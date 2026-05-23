import SwiftUI

@main
struct PicFacetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - app lives entirely in the menu bar
        // Menu bar is created by AppDelegate -> MenuBarController
        Settings {
            EmptyView()
        }
    }
}

