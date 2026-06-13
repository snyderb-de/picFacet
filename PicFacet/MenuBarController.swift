import AppKit
import SwiftUI
import PicFacetCore

final class MenuBarController {
    private let statusItem: NSStatusItem
    private var settingsWindow: NSWindow?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        NSLog("[MenuBar] Initializing menu bar...")
        
        configureButton()
        buildMenu()
        NSLog("[MenuBar] Menu bar initialized")
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            NSLog("[MenuBar] ERROR: No status item button!")
            return
        }
        
        NSLog("[MenuBar] Configuring button...")
        
        // Create custom icon: photo with diamond overlay
        if let customIcon = createMenuBarIcon() {
            button.image = customIcon
            button.image?.isTemplate = true
            NSLog("[MenuBar] Custom icon created")
        } else {
            // Fallback to SF Symbol
            button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                                   accessibilityDescription: "PicFacet")
            button.image?.isTemplate = true
            NSLog("[MenuBar] Using fallback icon")
        }
    }
    
    private func createMenuBarIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw photo icon (base layer)
            let photoIconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let photoIcon = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)?.withSymbolConfiguration(photoIconConfig) {
                let photoRect = NSRect(x: 1, y: 1, width: 16, height: 16)
                photoIcon.draw(in: photoRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
            
            // Draw diamond overlay (bottom right corner)
            let diamondConfig = NSImage.SymbolConfiguration(pointSize: 7, weight: .semibold)
            if let diamondIcon = NSImage(systemSymbolName: "diamond.fill", accessibilityDescription: nil)?.withSymbolConfiguration(diamondConfig) {
                let diamondRect = NSRect(x: 10, y: 1, width: 7, height: 7)
                diamondIcon.draw(in: diamondRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
            
            return true
        }
        
        image.isTemplate = true
        return image
    }

    private func buildMenu() {
        let menu = NSMenu()
        
        // Batch Processor
        let batchItem = NSMenuItem(title: "Batch Processor…",
                                   action: #selector(openBatchProcessor),
                                   keyEquivalent: "b")
        batchItem.target = self
        menu.addItem(batchItem)
        
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearanceMenu()
        menu.addItem(appearanceItem)

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

    private func appearanceMenu() -> NSMenu {
        let menu = NSMenu()
        let current = PicFacetSettings.shared.appAppearance

        for appearance in PicFacetSettings.AppAppearance.allCases {
            let item = NSMenuItem(
                title: appearance.menuTitle,
                action: #selector(setAppearance(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = appearance.rawValue
            item.state = appearance == current ? .on : .off
            menu.addItem(item)
        }

        return menu
    }
    
    @objc private func openBatchProcessor() {
        ProgressWindowController.shared.show()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = NSHostingView(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "PicFacet Settings"
            window.contentView = view
            window.minSize = NSSize(width: 520, height: 560)
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

    @objc private func setAppearance(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let appearance = PicFacetSettings.AppAppearance(rawValue: rawValue) else {
            return
        }

        PicFacetSettings.shared.appAppearance = appearance
        applyAppearance(appearance)
        buildMenu()
    }

    private func applyAppearance(_ appearance: PicFacetSettings.AppAppearance) {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

private extension PicFacetSettings.AppAppearance {
    var menuTitle: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
