import AppKit
import SwiftUI
import PicFacetCore

extension Notification.Name {
    static let picFacetAppearanceChanged = Notification.Name("picfacet.appearanceChanged")
}

/// Applies and persists the app-wide light/dark choice. One path for the menu
/// bar, the Settings window and the window-header toggle.
enum AppearanceController {
    static func set(_ value: PicFacetSettings.AppAppearance) {
        PicFacetSettings.shared.appAppearance = value
        apply(value)
        NotificationCenter.default.post(name: .picFacetAppearanceChanged, object: nil)
    }

    static func apply(_ value: PicFacetSettings.AppAppearance) {
        switch value {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// True when the app currently renders dark, whether forced or from the system.
    static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

/// Owns the single Settings window (menu bar item and header gear both open it).
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "PicFacet Settings"
            win.contentView = NSHostingView(rootView: SettingsView())
            win.minSize = NSSize(width: 520, height: 560)
            win.center()
            win.isReleasedWhenClosed = false
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// Light/dark toggle and Settings gear shown in the top corner of the Batch
/// and Chooser windows.
struct PFWindowControls: View {
    @State private var isDark = AppearanceController.isDark

    var body: some View {
        HStack(spacing: 8) {
            Button {
                AppearanceController.set(isDark ? .light : .dark)
            } label: {
                Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                    .frame(width: 16, height: 16)
            }
            .help(isDark ? "Switch to light appearance" : "Switch to dark appearance")

            Button {
                SettingsWindowController.shared.show()
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 16, height: 16)
            }
            .help("Settings")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .onReceive(NotificationCenter.default.publisher(for: .picFacetAppearanceChanged)) { _ in
            // The window re-renders with the new appearance a tick later.
            DispatchQueue.main.async { isDark = AppearanceController.isDark }
        }
    }
}
