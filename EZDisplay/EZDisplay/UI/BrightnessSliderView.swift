import SwiftUI

struct BrightnessSliderView: View {
    let display: DisplayModel
    @State private var debounceTask: DispatchWorkItem?

    @Environment(DisplayManager.self) private var displayManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))

                Slider(value: Binding(
                    get: { Double(display.brightness) },
                    set: { newValue in
                        debounceTask?.cancel()
                        let task = DispatchWorkItem {
                            displayManager.setBrightness(Float(newValue), for: display)
                        }
                        debounceTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: task)
                        display.brightness = Float(newValue)
                    }
                ), in: 0.0...1.0)
                .controlSize(.mini)

                Image(systemName: "sun.max")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))

                Text("\(Int(display.brightness * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }
}
