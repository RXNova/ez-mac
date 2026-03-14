import SwiftUI

struct DDCControlsView: View {
    let display: DisplayModel
    @Environment(DisplayManager.self) private var displayManager
    @State private var debounceTasks: [UInt8: DispatchWorkItem] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(display.ddcControls) { control in
                HStack(spacing: 6) {
                    Image(systemName: control.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .center)

                    Text(control.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 68, alignment: .leading)

                    Slider(value: Binding(
                        get: { Double(control.value) },
                        set: { newVal in
                            if let idx = display.ddcControls.firstIndex(where: { $0.id == control.id }) {
                                display.ddcControls[idx].value = Float(newVal)
                            }
                            debounceTasks[control.id]?.cancel()
                            let task = DispatchWorkItem {
                                displayManager.setDDCControl(Float(newVal), code: control.id, for: display)
                            }
                            debounceTasks[control.id] = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: task)
                        }
                    ), in: 0.0...1.0)
                    .controlSize(.mini)

                    Text("\(Int(control.value * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }
}
