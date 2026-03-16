import SwiftUI

struct ResolutionPickerView: View {
    let display: DisplayModel
    @Binding var showNonHiDPI: Bool
    @Environment(DisplayManager.self) private var displayManager

    private struct ResGroup: Identifiable {
        let id: String
        let label: String
        let modes: [DisplayMode]
        var highestRate: DisplayMode { modes[0] }
    }

    private var groups: [ResGroup] {
        var map: [String: ResGroup] = [:]
        for mode in display.availableModes {
            if !showNonHiDPI && !mode.isRetina { continue }
            let key = "\(mode.logicalWidth)x\(mode.logicalHeight)-\(mode.isRetina ? "1" : "0")"
            if var g = map[key] {
                g = ResGroup(id: g.id, label: g.label,
                             modes: (g.modes + [mode]).sorted { $0.refreshRate > $1.refreshRate })
                map[key] = g
            } else {
                let label = mode.isRetina ? "\(mode.shortLabel)  HiDPI" : mode.shortLabel
                map[key] = ResGroup(id: key, label: label, modes: [mode])
            }
        }
        return map.values.sorted {
            if $0.highestRate.logicalWidth != $1.highestRate.logicalWidth {
                return $0.highestRate.logicalWidth > $1.highestRate.logicalWidth
            }
            return $0.highestRate.isRetina && !$1.highestRate.isRetina
        }
    }

    private var currentGroupID: String {
        guard let m = display.currentMode else { return "" }
        return "\(m.logicalWidth)x\(m.logicalHeight)-\(m.isRetina ? "1" : "0")"
    }

    private var currentRefreshRates: [DisplayMode] {
        groups.first { $0.id == currentGroupID }?.modes ?? []
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Resolution")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { currentGroupID },
                    set: { key in
                        guard let group = groups.first(where: { $0.id == key }) else { return }
                        displayManager.applyMode(group.highestRate, to: display)
                    }
                )) {
                    ForEach(groups) { group in
                        Text(group.label).tag(group.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Refresh Rate")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { display.currentMode?.id ?? "" },
                    set: { id in
                        guard let mode = display.availableModes.first(where: { $0.id == id }) else { return }
                        displayManager.applyMode(mode, to: display)
                    }
                )) {
                    ForEach(currentRefreshRates) { mode in
                        let hz = mode.refreshRate.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(mode.refreshRate)) Hz"
                            : String(format: "%.2f Hz", mode.refreshRate)
                        Text(hz).tag(mode.id)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }
}
