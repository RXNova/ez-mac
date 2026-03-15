import SwiftUI

struct MenuBarView: View {
    let closeAction: () -> Void
    @Environment(DisplayManager.self) private var displayManager
    @State private var showNonHiDPI = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "display.2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("EZDisplay")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    displayManager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh displays")

                Button {
                    closeAction()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close (right-click menu bar icon to Quit)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Global HiDPI toggle
            HStack(spacing: 3) {
                Toggle(isOn: $showNonHiDPI) {
                    HStack(spacing: 3) {
                        Text("Show non-HiDPI resolutions")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                            .help("HiDPI (Retina) modes render at 2× pixel density for sharper text and graphics. Non-HiDPI modes run at native pixel count with no scaling.")
                    }
                }
                .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            if displayManager.displays.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No displays found")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(displayManager.displays) { display in
                            DisplayRowView(display: display, showNonHiDPI: $showNonHiDPI)
                        }

                        if let error = displayManager.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 11))
                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(10)
                    .frame(width: 300)   // anchor width so height is deterministic
                }
                .frame(width: 300, height: 460)
            }
        }
        .frame(width: 300)
        .background(.regularMaterial)
        .task {
            // Periodically check brightness when the UI is visible.
            while !Task.isCancelled {
                // Poll every 1 second
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                displayManager.updateBrightness()
            }
        }
    }
}
