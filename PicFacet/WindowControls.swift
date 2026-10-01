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

/// Square icon button used in the status bar: its own quiet background, no
/// shared capsule, brighter on hover.
struct PFBarButton: View {
    let systemImage: String
    let help: String
    var isEnabled = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)
                .frame(width: 26, height: 22)
                .background(
                    PFDesign.surfaceLow.opacity(hovering && isEnabled ? 1 : 0.55),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(PFDesign.outlineVariant.opacity(0.2), lineWidth: 1)
                }
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// Thin bar along the bottom of the Batch and Chooser windows: app-level
/// buttons on the left, a status readout on the right. Add new buttons in
/// `buttons`; they're separate squares, so the row can grow.
struct PFStatusBar: View {
    /// Right-aligned readout, e.g. "3 images · 4.2 MB".
    var status: String = ""

    @State private var isDark = AppearanceController.isDark

    var body: some View {
        HStack(spacing: 8) {
            PFBarButton(systemImage: "gearshape", help: "Settings") {
                SettingsWindowController.shared.show()
            }
            PFBarButton(systemImage: isDark ? "sun.max" : "moon",
                        help: isDark ? "Switch to light appearance" : "Switch to dark appearance") {
                AppearanceController.set(isDark ? .light : .dark)
            }
            // Placeholder until the manual exists.
            PFBarButton(systemImage: "book.closed", help: "User manual (coming soon)", isEnabled: false) {}

            Spacer()

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
        .background(PFDesign.chrome.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(PFDesign.outlineVariant.opacity(0.2)).frame(height: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .picFacetAppearanceChanged)) { _ in
            // The window re-renders with the new appearance a tick later.
            DispatchQueue.main.async { isDark = AppearanceController.isDark }
        }
    }
}
