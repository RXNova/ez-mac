import AppKit
import SwiftUI

@Observable
private final class OSDState {
    var fraction: Double = 0
    var displayName: String = ""
}

private struct BrightnessOSDView: View {
    var state: OSDState

    var body: some View {
        VStack(spacing: 8) {
            Text(state.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Image(systemName: "sun.min.fill").foregroundStyle(.white).font(.system(size: 12))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2)).frame(height: 3)
                        Capsule().fill(Color.white).frame(width: geo.size.width * CGFloat(state.fraction), height: 3)
                    }.frame(maxHeight: .infinity)
                }.frame(height: 3)
                Image(systemName: "sun.max.fill").foregroundStyle(.white).font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(white: 0.18, opacity: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

@MainActor
final class BrightnessOSDController {
    static let shared = BrightnessOSDController()
    private init() {}
    private var window: NSWindow?
    private let state = OSDState()
    private var hideTask: Task<Void, Never>?

    func show(brightness: Float, displayID: CGDirectDisplayID) {
        state.fraction = Double(max(0, min(1, brightness)))
        state.displayName = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        })?.localizedName ?? "Display"

        if window == nil {
            let hosting = NSHostingView(rootView: BrightnessOSDView(state: state))
            hosting.frame = NSRect(x: 0, y: 0, width: 296, height: 68)
            let w = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.ignoresMouseEvents = true
            w.contentView = hosting
            window = w
        }

        let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }) ?? NSScreen.main
        if let screen {
            let sf = screen.visibleFrame, sz = window!.frame.size
            window?.setFrameOrigin(NSPoint(x: sf.maxX - sz.width - 20, y: sf.maxY - sz.height - 8))
        }
        window?.alphaValue = 1
        window?.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { $0.duration = 0.35; self?.window?.animator().alphaValue = 0 }
            self?.window?.orderOut(nil)
        }
    }
}






