import CoreGraphics
import Foundation

enum ResolutionError: LocalizedError {
    case beginConfigurationFailed
    case applyModeFailed(CGError)
    case completeConfigurationFailed(CGError)

    var errorDescription: String? {
        switch self {
        case .beginConfigurationFailed: return "Failed to begin display configuration"
        case .applyModeFailed(let e): return "Failed to apply display mode (error \(e.rawValue))"
        case .completeConfigurationFailed(let e): return "Failed to complete display configuration (error \(e.rawValue))"
        }
    }
}

final class ResolutionService {
    static let shared = ResolutionService()
    private init() {}

    func availableModes(for displayID: CGDirectDisplayID) -> [DisplayMode] {
        let options: CFDictionary = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue as Any
        ] as CFDictionary

        guard let rawModes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
            return []
        }

        var seen = Set<String>()
        return rawModes.compactMap { DisplayMode(mode: $0) }.filter { mode in
            let key = mode.id
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    func currentMode(for displayID: CGDirectDisplayID) -> DisplayMode? {
        guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return DisplayMode(mode: mode)
    }

    func apply(mode: DisplayMode, to displayID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            throw ResolutionError.beginConfigurationFailed
        }

        let applyError = CGConfigureDisplayWithDisplayMode(config, displayID, mode.mode, nil)
        guard applyError == .success else {
            CGCancelDisplayConfiguration(config)
            throw ResolutionError.applyModeFailed(applyError)
        }

        let completeError = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeError == .success else {
            throw ResolutionError.completeConfigurationFailed(completeError)
        }
    }
}
