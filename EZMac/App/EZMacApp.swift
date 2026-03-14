import SwiftUI

@main
struct EZMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — pure menu bar app
        Settings { EmptyView() }
    }
}
