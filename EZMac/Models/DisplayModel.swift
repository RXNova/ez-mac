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

    init(id: CGDirectDisplayID, name: String, isInternal: Bool, isMain: Bool) {
        self.id = id
        self.name = name
        self.isInternal = isInternal
        self.isMain = isMain
    }

    var groupedModes: [(resolution: String, modes: [DisplayMode])] {
        let sorted = availableModes.sorted {
            if $0.logicalWidth != $1.logicalWidth { return $0.logicalWidth > $1.logicalWidth }
            if $0.logicalHeight != $1.logicalHeight { return $0.logicalHeight > $1.logicalHeight }
            return $0.refreshRate > $1.refreshRate
        }
        var groups: [(resolution: String, modes: [DisplayMode])] = []
        var seen: [String: Int] = [:]
        for mode in sorted {
            let key = mode.shortLabel
            if let idx = seen[key] { groups[idx].modes.append(mode) }
            else { seen[key] = groups.count; groups.append((resolution: key, modes: [mode])) }
        }
        return groups
    }
}
