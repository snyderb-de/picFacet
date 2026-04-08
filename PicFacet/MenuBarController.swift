import AppKit
import SwiftUI

final class MenuBarController {
    private let statusItem: NSStatusItem
    private var settingsWindow: NSWindow?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        buildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                               accessibilityDescription: "PicFacet")
        button.image?.isTemplate = true
    }

    private func buildMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let howTo = NSMenuItem(title: "How to enable Quick Actions…",
                               action: #selector(openOnboarding),
                               keyEquivalent: "")
        howTo.target = self
        menu.addItem(howTo)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit PicFacet",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = NSHostingView(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "PicFacet Settings"
            window.contentView = view
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openOnboarding() {
        OnboardingWindowController.shared.show()
    }

    // MARK: - Progress (Phase 6)

    func showProgress() { }
    func hideProgress() { }
}
