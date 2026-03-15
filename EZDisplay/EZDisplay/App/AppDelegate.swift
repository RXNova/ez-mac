import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var displayManager: DisplayManager?
    private let brightnessKeyMonitor = BrightnessKeyMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let manager = DisplayManager()
        self.displayManager = manager
        self.menuBarController = MenuBarController(displayManager: manager)
        brightnessKeyMonitor.start(displayManager: manager)
    }

    func applicationWillTerminate(_ notification: Notification) {
        brightnessKeyMonitor.stop()
        displayManager?.restoreAllDisplays()
    }
}
