import CoreGraphics
import Foundation

final class BrightnessService {
    static let shared = BrightnessService()
    private init() {}

    func getBrightness(for display: DisplayModel, completion: @escaping (Float?) -> Void) {
        if display.isInternal {
            completion(InternalBrightnessDriver.shared.getBrightness(for: display.id))
            return
        }
        DDCBrightnessDriver.shared.getBrightness(for: display.id) { completion($0) }
    }

    func setBrightness(_ value: Float, for display: DisplayModel) {
        let v = max(0.0, min(1.0, value))
        if display.isInternal {
            InternalBrightnessDriver.shared.setBrightness(v, for: display.id)
            return
        }
        DDCBrightnessDriver.shared.setBrightness(v, for: display.id)
    }

    func detectBrightnessSupport(for display: DisplayModel) -> Bool {
        if display.isInternal {
            return InternalBrightnessDriver.shared.supportsBrightness(for: display.id)
        }
        return true
    }
}
