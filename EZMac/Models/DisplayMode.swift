import CoreGraphics
import Foundation

struct DisplayMode: Identifiable, Hashable {
    let id: String
    let mode: CGDisplayMode
    let logicalWidth: Int
    let logicalHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    let isRetina: Bool
    let isNative: Bool
    let isUsable: Bool

    init?(mode: CGDisplayMode) {
        guard mode.isUsableForDesktopGUI() else { return nil }

        self.mode = mode
        self.logicalWidth = mode.width
        self.logicalHeight = mode.height
        self.pixelWidth = mode.pixelWidth
        self.pixelHeight = mode.pixelHeight
        self.refreshRate = mode.refreshRate == 0 ? 60.0 : mode.refreshRate
        self.isRetina = pixelWidth == logicalWidth * 2 && pixelHeight == logicalHeight * 2
        let ioFlags = mode.ioFlags
        self.isNative = (ioFlags & UInt32(kDisplayModeNativeFlag)) != 0
        self.isUsable = (ioFlags & UInt32(kDisplayModeSafeFlag)) != 0
        self.id = "\(logicalWidth)x\(logicalHeight)@\(Int(refreshRate))-\(isRetina ? "HiDPI" : "LoDPI")"
    }

    var label: String {
        let retina = isRetina ? " (HiDPI)" : ""
        let hz = refreshRate.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(refreshRate))Hz"
            : String(format: "%.2fHz", refreshRate)
        return "\(logicalWidth) × \(logicalHeight)\(retina)  \(hz)"
    }

    var shortLabel: String {
        "\(logicalWidth) × \(logicalHeight)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayMode, rhs: DisplayMode) -> Bool {
        lhs.id == rhs.id
    }
}
