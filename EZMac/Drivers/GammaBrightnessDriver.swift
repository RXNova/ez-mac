import CoreGraphics
import Foundation

/// Software brightness via gamma table manipulation.
/// Works on any display without DDC or IOKit access.
/// Brightness range: 0.0 (very dim) – 1.0 (full, restores original gamma).
final class GammaBrightnessDriver {
    static let shared = GammaBrightnessDriver()

    private var originalTables: [CGDirectDisplayID: GammaTable] = [:]
    private let tableSize = 256

    private struct GammaTable {
        var red:   [CGGammaValue]
        var green: [CGGammaValue]
        var blue:  [CGGammaValue]
    }

    private init() {}

    func setBrightness(_ value: Float, for displayID: CGDirectDisplayID) {
        // Capture original table once so we can restore it
        if originalTables[displayID] == nil {
            captureOriginal(for: displayID)
        }
        guard let orig = originalTables[displayID] else { return }
        let brightness = CGGammaValue(max(0.05, min(1.0, value)))

        var r = orig.red.map   { $0 * brightness }
        var g = orig.green.map { $0 * brightness }
        var b = orig.blue.map  { $0 * brightness }
        CGSetDisplayTransferByTable(displayID, UInt32(tableSize), &r, &g, &b)
    }

    func getBrightness(for displayID: CGDirectDisplayID) -> Float? {
        guard let orig = originalTables[displayID] else { return nil }
        var r = [CGGammaValue](repeating: 0, count: tableSize)
        var g = [CGGammaValue](repeating: 0, count: tableSize)
        var b = [CGGammaValue](repeating: 0, count: tableSize)
        var count: UInt32 = 0
        CGGetDisplayTransferByTable(displayID, UInt32(tableSize), &r, &g, &b, &count)
        guard count > 0, let origMax = orig.red.last, origMax > 0, let curMax = r.last else { return nil }
        return Float(curMax / origMax)
    }

    func restore(for displayID: CGDirectDisplayID) {
        CGDisplayRestoreColorSyncSettings()
        originalTables.removeValue(forKey: displayID)
    }

    private func captureOriginal(for displayID: CGDirectDisplayID) {
        var r = [CGGammaValue](repeating: 0, count: tableSize)
        var g = [CGGammaValue](repeating: 0, count: tableSize)
        var b = [CGGammaValue](repeating: 0, count: tableSize)
        var count: UInt32 = 0
        CGGetDisplayTransferByTable(displayID, UInt32(tableSize), &r, &g, &b, &count)
        // If table is empty/identity, build a linear one to avoid zeroing everything
        if count == 0 || r.last == 0 {
            let linear = (0..<tableSize).map { CGGammaValue($0) / CGGammaValue(tableSize - 1) }
            originalTables[displayID] = GammaTable(red: linear, green: linear, blue: linear)
        } else {
            originalTables[displayID] = GammaTable(red: r, green: g, blue: b)
        }
    }
}
