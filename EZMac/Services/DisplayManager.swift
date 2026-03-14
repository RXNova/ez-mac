import CoreGraphics
import Foundation
import Observation
import AppKit

// macOS 26+: SkyLight SLS API — mirrors CGConfigureDisplayEnabled(CGDisplayConfigRef, displayID, Bool)
private typealias SLSConfigureDisplayEnabledFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError
// macOS 12–15: CoreDisplay API (removed in macOS 26)
private typealias CoreDisplaySetUserEnabledFn  = @convention(c) (CGDirectDisplayID, Bool) -> Int32

@Observable
@MainActor
final class DisplayManager {
    var displays: [DisplayModel] = []
    var errorMessage: String?

    private var slsConfigureDisplayEnabled: SLSConfigureDisplayEnabledFn?
    private var coreDisplaySetUserEnabled: CoreDisplaySetUserEnabledFn?
    // Tracks displays we software-disconnected so they still appear in the list
    private var softwareDisconnected: [CGDirectDisplayID: (name: String, isInternal: Bool)] = [:]

    init() {
        // Prefer SkyLight (macOS 26+)
        if let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
           let sym = dlsym(handle, "SLSConfigureDisplayEnabled") {
            slsConfigureDisplayEnabled = unsafeBitCast(sym, to: SLSConfigureDisplayEnabledFn.self)
        }
        // Fallback: CoreDisplay (macOS 12–15)
        if slsConfigureDisplayEnabled == nil,
           let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY),
           let sym = dlsym(handle, "CoreDisplay_Display_SetUserEnabled") {
            coreDisplaySetUserEnabled = unsafeBitCast(sym, to: CoreDisplaySetUserEnabledFn.self)
        }
        refresh()
        CGDisplayRegisterReconfigurationCallback(reconfigCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback(reconfigCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    func refresh() {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displayIDs, &displayCount) == .success else {
            errorMessage = "Failed to enumerate displays"
            return
        }

        let screens = NSScreen.screens
        var newDisplays: [DisplayModel] = []

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let isEnabled = CGDisplayIsActive(displayID) != 0

            // Preserve name from existing model when display is disabled (not in NSScreen)
            let existingName = displays.first { $0.id == displayID }?.name
            let name = screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
            }?.localizedName ?? existingName ?? "Display \(displayID)"

            let model = DisplayModel(
                id: displayID,
                name: name,
                isInternal: CGDisplayIsBuiltin(displayID) != 0,
                isMain: CGDisplayIsMain(displayID) != 0
            )
            model.isEnabled = isEnabled

            if isEnabled {
                model.availableModes = ResolutionService.shared.availableModes(for: displayID)
                model.currentMode = ResolutionService.shared.currentMode(for: displayID)
                model.supportsBrightness = BrightnessService.shared.detectBrightnessSupport(for: model)
                if model.supportsBrightness {
                    BrightnessService.shared.getBrightness(for: model) { value in
                        if let value { model.brightness = value }
                    }
                }
                if !model.isInternal {
                    DDCBrightnessDriver.shared.probeVCPs(DDCControl.probeCodes, for: displayID) { results in
                        model.ddcControls = results.map { DDCControl(code: $0.code, current: $0.current, max: $0.max) }
                    }
                }
            }

            newDisplays.append(model)
        }

        let onlineIDs = Set(displayIDs[0..<Int(displayCount)])
        // If a software-disconnected display reappears (physical reconnect), stop tracking it
        for id in softwareDisconnected.keys where onlineIDs.contains(id) && CGDisplayIsActive(id) != 0 {
            softwareDisconnected.removeValue(forKey: id)
        }

        displays = newDisplays.sorted {
            if $0.isEnabled != $1.isEnabled { return $0.isEnabled }
            if $0.isMain != $1.isMain { return $0.isMain }
            return $0.name < $1.name
        }

        // Append any software-disconnected displays not already in the online list
        for (id, info) in softwareDisconnected where !onlineIDs.contains(id) {
            let model = DisplayModel(id: id, name: info.name, isInternal: info.isInternal, isMain: false)
            model.isEnabled = false
            displays.append(model)
        }
    }

    func applyMode(_ mode: DisplayMode, to display: DisplayModel) {
        do {
            try ResolutionService.shared.apply(mode: mode, to: display.id)
            display.currentMode = mode
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setBrightness(_ value: Float, for display: DisplayModel) {
        display.brightness = value
        BrightnessService.shared.setBrightness(value, for: display)
    }

    func setDDCControl(_ value: Float, code: UInt8, for display: DisplayModel) {
        DDCBrightnessDriver.shared.setVCP(code, value: value, for: display.id)
    }

    func setDisplayEnabled(_ enabled: Bool, for display: DisplayModel) {
        guard !display.isInternal else { return }
        errorMessage = nil

        if let enableFn = slsConfigureDisplayEnabled {
            // macOS 26+: SkyLight SLS API — requires CG display config transaction
            var config: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&config) == .success else {
                errorMessage = "Failed to begin display configuration"
                return
            }
            let err = enableFn(config, display.id, enabled)
            guard err == .success else {
                CGCancelDisplayConfiguration(config)
                errorMessage = "Failed to \(enabled ? "enable" : "disable") display (error \(err.rawValue))"
                return
            }
            guard CGCompleteDisplayConfiguration(config, .forAppOnly) == .success else {
                errorMessage = "Failed to complete display configuration"
                return
            }
        } else if let fn = coreDisplaySetUserEnabled {
            // macOS 12–15: CoreDisplay API
            let result = fn(display.id, enabled)
            if result != 0 {
                errorMessage = "Failed to \(enabled ? "enable" : "disable") display (error \(result))"
                return
            }
        } else {
            errorMessage = "Display disconnect is not supported on this macOS version"
            return
        }

        if !enabled {
            softwareDisconnected[display.id] = (name: display.name, isInternal: display.isInternal)
        } else {
            softwareDisconnected.removeValue(forKey: display.id)
        }
        display.isEnabled = enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.refresh()
        }
    }
}

private func reconfigCallback(
    displayID: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    guard let ptr = userInfo else { return }
    let manager = Unmanaged<DisplayManager>.fromOpaque(ptr).takeUnretainedValue()
    DispatchQueue.main.async { manager.refresh() }
}
