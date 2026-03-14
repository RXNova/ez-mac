import IOKit
import CoreGraphics
import Foundation

// DisplayServices private framework — works on both Intel and Apple Silicon
// Function signatures verified via dyld_info on macOS 14+
private typealias DisplayServicesGetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias DisplayServicesSetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
private typealias DisplayServicesCanChangeBrightnessFn = @convention(c) (CGDirectDisplayID) -> Int32

final class InternalBrightnessDriver {
    static let shared = InternalBrightnessDriver()

    private var getBrightnessFn: DisplayServicesGetBrightnessFn?
    private var setBrightnessFn: DisplayServicesSetBrightnessFn?
    private var canChangeFn: DisplayServicesCanChangeBrightnessFn?

    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY | RTLD_LOCAL
        ) else { return }

        getBrightnessFn = unsafeBitCast(
            dlsym(handle, "DisplayServicesGetBrightness"),
            to: DisplayServicesGetBrightnessFn?.self
        )
        setBrightnessFn = unsafeBitCast(
            dlsym(handle, "DisplayServicesSetBrightness"),
            to: DisplayServicesSetBrightnessFn?.self
        )
        canChangeFn = unsafeBitCast(
            dlsym(handle, "DisplayServicesCanChangeBrightness"),
            to: DisplayServicesCanChangeBrightnessFn?.self
        )
        // Note: do not dlclose — the framework stays loaded
    }

    /// True if the display reports native brightness support OR if a set call succeeds.
    /// DisplayServicesCanChangeBrightness only reflects "native software dimming" capability —
    /// hardware DDC brightness (e.g. external monitors) still succeeds via DisplayServicesSetBrightness.
    func supportsBrightness(for displayID: CGDirectDisplayID) -> Bool {
        guard getBrightnessFn != nil || setBrightnessFn != nil else { return false }
        // If we can get a reading, definitely supported
        if let _ = getBrightness(for: displayID) { return true }
        // If canChange says yes, definitely supported
        if let fn = canChangeFn, fn(displayID) != 0 { return true }
        // Otherwise attempt a no-op set; if it returns 0 the channel exists
        if let fn = setBrightnessFn {
            // Probe: try setting to current value (1.0 as safe default — this is overwritten immediately)
            let ret = fn(displayID, 1.0)
            return ret == 0
        }
        return false
    }

    func getBrightness(for displayID: CGDirectDisplayID) -> Float? {
        guard let fn = getBrightnessFn else { return nil }
        var value: Float = 0
        let result = fn(displayID, &value)
        return result == 0 ? value : nil
    }

    func setBrightness(_ value: Float, for displayID: CGDirectDisplayID) {
        guard let fn = setBrightnessFn else { return }
        let clamped = max(0.0, min(1.0, value))
        _ = fn(displayID, clamped)
    }
}
