import SwiftUI

struct DisplayRowView: View {
    let display: DisplayModel
    @Binding var showNonHiDPI: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: display.isInternal ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(display.name)
                            .font(.system(size: 13, weight: .semibold))
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
                    if let mode = display.currentMode {
                        Text("\(mode.logicalWidth) × \(mode.logicalHeight)\(mode.isRetina ? " (HiDPI)" : "")")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            ResolutionPickerView(display: display, showNonHiDPI: $showNonHiDPI)

            if display.supportsBrightness {
                BrightnessSliderView(display: display)
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
