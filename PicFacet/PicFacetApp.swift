import SwiftUI

@main
struct PicFacetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window shown at launch — app lives in the menu bar.
        // Settings scene is opened by MenuBarController.
        Settings {
            SettingsView()
        }
    }
}
