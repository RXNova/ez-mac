import SwiftUI

private let kPrimaryCodes: Set<UInt8> = [0x10, 0x62] // Brightness, Volume

struct DDCControlsView: View {
    let display: DisplayModel
    @Environment(DisplayManager.self) private var displayManager
    @State private var debounceTasks: [UInt8: DispatchWorkItem] = [:]
    @State private var expanded = false

    private var primaryControls: [DDCControl] {
        display.ddcControls.filter { kPrimaryCodes.contains($0.id) }
    }

    private var secondaryControls: [DDCControl] {
        display.ddcControls.filter { !kPrimaryCodes.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(primaryControls) { control in
                controlRow(control)
            }

            if !secondaryControls.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(secondaryControls) { control in
                            controlRow(control)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func controlRow(_ control: DDCControl) -> some View {
        HStack(spacing: 6) {
            Image(systemName: control.icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)

            Slider(value: Binding(
                get: { Double(control.value) },
                set: { newVal in
                    if let idx = display.ddcControls.firstIndex(where: { $0.id == control.id }) {
                        display.ddcControls[idx].value = Float(newVal)
                    }
                    if control.id == 0x10 {
                        BrightnessOSDController.shared.show(brightness: Float(newVal), displayID: display.id)
                    }
                    debounceTasks[control.id]?.cancel()
                    let task = DispatchWorkItem {
                        displayManager.setDDCControl(Float(newVal), code: control.id, for: display)
                    }
                    debounceTasks[control.id] = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: task)
                }
            ), in: 0.0...1.0)
            .controlSize(.regular)

            Text("\(Int(control.value * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}
