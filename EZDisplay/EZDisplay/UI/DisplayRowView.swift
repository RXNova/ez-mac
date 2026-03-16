import SwiftUI

struct DisplayRowView: View {
    let display: DisplayModel
    @Binding var showNonHiDPI: Bool
    @Environment(DisplayManager.self) private var displayManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: display.isInternal ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(display.isEnabled ? Color.blue : Color.gray)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(display.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(display.isEnabled ? .primary : .secondary)
                        if display.isMain {
                            Text("Main")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                    if !display.isEnabled {
                        Text("Disconnected")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle(isOn: Binding(
                    get: { display.isEnabled },
                    set: { displayManager.setDisplayEnabled($0, for: display) }
                )) { EmptyView() }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(display.isEnabled && displayManager.displays.filter(\.isEnabled).count <= 1)
                .help(display.isEnabled && displayManager.displays.filter(\.isEnabled).count <= 1
                    ? "Cannot disconnect the only active display"
                    : display.isEnabled ? "Disconnect display" : "Reconnect display")
            }
            .padding(12)

            if display.isEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    ResolutionPickerView(display: display, showNonHiDPI: $showNonHiDPI)

                    if display.isInternal && display.supportsBrightness {
                        BrightnessSliderView(display: display)
                    } else if !display.isInternal && !display.ddcControls.isEmpty {
                        DDCControlsView(display: display)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(display.isEnabled ? 0.6 : 0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}
