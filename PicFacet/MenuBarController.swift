import AppKit
import SwiftUI
import PicFacetCore

final class MenuBarController {
    private let statusItem: NSStatusItem
    private var settingsWindow: NSWindow?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        NSLog("[MenuBar] Initializing menu bar...")
        
        // TEMPORARY DEBUG: Show emoji to confirm menu bar is working
        if let button = statusItem.button {
            button.title = "📷"
            NSLog("[MenuBar] Set temporary emoji icon")
        }
        
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
    
    @objc private func openBatchProcessor() {
        ProgressWindowController.shared.show()
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
}
