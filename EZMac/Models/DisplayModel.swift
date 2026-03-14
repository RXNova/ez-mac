import CoreGraphics
import Foundation
import Observation

@Observable
final class DisplayModel: Identifiable {
    let id: CGDirectDisplayID
    var name: String
    var currentMode: DisplayMode?
    var availableModes: [DisplayMode] = []
    var brightness: Float = 1.0
    var isInternal: Bool
    var supportsBrightness: Bool = false
    var isMain: Bool
    var ddcControls: [DDCControl] = []

    init(id: CGDirectDisplayID, name: String, isInternal: Bool, isMain: Bool) {
        self.id = id
        self.name = name
        self.isInternal = isInternal
        self.isMain = isMain
    }

}
