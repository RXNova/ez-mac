import CoreGraphics
import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class DisplayManager {
    var displays: [DisplayModel] = []
    var errorMessage: String?

    init() {
        refresh()
        CGDisplayRegisterReconfigurationCallback(reconfigCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback(reconfigCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    func refresh() {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displayIDs, &displayCount) == .success else {
            errorMessage = "Failed to enumerate displays"
            return
        }

        let screens = NSScreen.screens
        var newDisplays: [DisplayModel] = []

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let name = screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
            }?.localizedName ?? "Display \(displayID)"

            let model = DisplayModel(
                id: displayID,
                name: name,
                isInternal: CGDisplayIsBuiltin(displayID) != 0,
                isMain: CGDisplayIsMain(displayID) != 0
            )
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
            newDisplays.append(model)
        }

        displays = newDisplays.sorted {
            if $0.isMain != $1.isMain { return $0.isMain }
            return $0.name < $1.name
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
}

private func reconfigCallback(
    displayID: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    guard flags.contains(.setModeFlag) || flags.contains(.addFlag) || flags.contains(.removeFlag) else { return }
    guard let ptr = userInfo else { return }
    let manager = Unmanaged<DisplayManager>.fromOpaque(ptr).takeUnretainedValue()
    DispatchQueue.main.async { manager.refresh() }
}
