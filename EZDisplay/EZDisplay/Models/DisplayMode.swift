import CoreGraphics
import Foundation

struct DisplayMode: Identifiable, Hashable {
    let id: String
    let mode: CGDisplayMode
    let logicalWidth: Int
    let logicalHeight: Int
    let refreshRate: Double
    let isRetina: Bool

    init?(mode: CGDisplayMode) {
        guard mode.isUsableForDesktopGUI() else { return nil }

        self.mode = mode
        self.logicalWidth = mode.width
        self.logicalHeight = mode.height
        self.refreshRate = mode.refreshRate == 0 ? 60.0 : mode.refreshRate
        self.isRetina = mode.pixelWidth == mode.width * 2 && mode.pixelHeight == mode.height * 2
        self.id = "\(logicalWidth)x\(logicalHeight)@\(Int(refreshRate))-\(isRetina ? "HiDPI" : "LoDPI")"
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
