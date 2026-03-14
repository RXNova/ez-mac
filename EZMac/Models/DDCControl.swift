import Foundation

struct DDCControl: Identifiable {
    let id: UInt8       // VCP code
    let name: String
    let icon: String    // SF Symbol
    var value: Float    // 0...1 normalized

    static let probeCodes: [UInt8] = [0x10, 0x12, 0x62, 0x87, 0x8A]

    static func metadata(for code: UInt8) -> (name: String, icon: String) {
        switch code {
        case 0x10: return ("Brightness", "sun.max")
        case 0x12: return ("Contrast",   "circle.lefthalf.filled")
        case 0x62: return ("Volume",     "speaker.wave.2")
        case 0x87: return ("Sharpness",  "scope")
        case 0x8A: return ("Saturation", "drop")
        default:   return ("Control \(String(format: "%02X", code))", "slider.horizontal.3")
        }
    }

    init(code: UInt8, current: UInt16, max: UInt16) {
        self.id = code
        let meta = DDCControl.metadata(for: code)
        self.name = meta.name
        self.icon = meta.icon
        let effectiveMax: UInt16 = max > 0 ? max : 100
        self.value = Float(current) / Float(effectiveMax)
    }
}
