import AppKit
import CoreGraphics

// Intercepts F1/F2 brightness keys. On an external display, consumes the
// event and adjusts DDC brightness. On the built-in display, passes through.
// Requires Accessibility permission (prompts automatically, retries until granted).
final class BrightnessKeyMonitor {

    private weak var displayManager: DisplayManager?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    // Cached on main thread; read from event tap callback thread.
    private var displayMap: [CGDirectDisplayID: Bool] = [:]

    private let step: Float = 1.0 / 16.0

    func start(displayManager: DisplayManager) {
        self.displayManager = displayManager
        rebuildDisplayMap()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        attemptInstall()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    @objc private func screensChanged() {
        rebuildDisplayMap()
    }

    private func rebuildDisplayMap() {
        var map: [CGDirectDisplayID: Bool] = [:]
        for screen in NSScreen.screens {
            if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                map[id] = CGDisplayIsBuiltin(id) != 0
            }
        }
        displayMap = map
    }

    private func attemptInstall() {
        if AXIsProcessTrusted() {
            Task { @MainActor [weak self] in self?.displayManager?.needsAccessibility = false }
            installTap()
        } else {
            Task { @MainActor [weak self] in self?.displayManager?.needsAccessibility = true }
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                if AXIsProcessTrusted() {
                    t.invalidate()
                    self.permissionTimer = nil
                    Task { @MainActor [weak self] in self?.displayManager?.needsAccessibility = false }
                    self.installTap()
                }
            }
        }
    }

    private func installTap() {
        guard eventTap == nil else { return }
        // cghidEventTap: lowest level, before the OS processes media keys.
        // Intercept both systemDefined (default fn key mode) and keyDown (fn key mode).
        let mask: CGEventMask = (1 << 14) | (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<BrightnessKeyMonitor>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                    .handle(event, type: type)
            },
            userInfo: selfPtr
        )

        guard let tap = eventTap else { return }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        runLoopSource = src
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        var brightUp: Bool

        if type == CGEventType(rawValue: 14) {
            guard let ns = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
            let keyCode = (ns.data1 & 0xFFFF0000) >> 16
            let flags   = (ns.data1 & 0x0000FF00) >> 8
            // key-down (0x0A), brightness up (2) / down (3)
            guard flags == 0x0A, keyCode == 2 || keyCode == 3 else {
                return Unmanaged.passUnretained(event)
            }
            brightUp = (keyCode == 2)
        } else if type == .keyDown {
            // "Use F1/F2 as standard function keys" mode: F1=122 (↓), F2=120 (↑)
            let kc = event.getIntegerValueField(.keyboardEventKeycode)
            guard kc == 122 || kc == 120 else { return Unmanaged.passUnretained(event) }
            brightUp = (kc == 120)
        } else {
            return Unmanaged.passUnretained(event)
        }

        var displayID: CGDirectDisplayID = 0
        var count: UInt32 = 0
        CGGetDisplaysWithPoint(event.location, 1, &displayID, &count)

        guard count > 0 else { return Unmanaged.passUnretained(event) }

        let isBuiltin = displayMap[displayID] ?? (CGDisplayIsBuiltin(displayID) != 0)
        guard !isBuiltin else { return Unmanaged.passUnretained(event) }

        Task { @MainActor [weak self] in
            self?.applyBrightness(displayID: displayID, up: brightUp)
        }
        return nil
    }

    @MainActor
    private func applyBrightness(displayID: CGDirectDisplayID, up: Bool) {
        guard
            let manager = displayManager,
            let display = manager.displays.first(where: { $0.id == displayID }),
            display.isEnabled,
            display.supportsBrightness
        else { return }

        let current: Float = display.ddcControls.first(where: { $0.id == 0x10 })?.value ?? display.brightness
        let newValue = max(0, min(1, current + (up ? step : -step)))
        manager.setBrightness(newValue, for: display)
    }
}


