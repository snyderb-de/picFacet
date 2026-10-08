import AppKit
import SwiftUI
import PicFacetCore

final class MenuBarController {
    private let statusItem: NSStatusItem
    private var idleImage: NSImage?
    /// Top menu row while batches run: "Processing 3 of 10 files…".
    private let progressItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let progressSeparator = NSMenuItem.separator()
    private var doneReset: DispatchWorkItem?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        NSLog("[MenuBar] Initializing menu bar...")
        
        configureButton()
        buildMenu()
        RunProgress.shared.onChange = { [weak self] in self?.progressChanged() }
        NSLog("[MenuBar] Menu bar initialized")
    }

    // MARK: - Progress

    /// While anything runs, the icon becomes a ring filling with progress;
    /// when the last run ends it shows a checkmark briefly, then goes back.
    private func progressChanged() {
        let progress = RunProgress.shared
        guard let button = statusItem.button else { return }
        doneReset?.cancel()

        progressItem.isHidden = !progress.isRunning
        progressSeparator.isHidden = !progress.isRunning

        if progress.isRunning {
            button.image = Self.ringImage(fraction: progress.fraction)
            button.toolTip = progress.label
            progressItem.title = progress.label
            return
        }

        button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Done")
        button.image?.isTemplate = true
        button.toolTip = "PicFacet"
        let reset = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.image = self?.idleImage
        }
        doneReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: reset)
    }

    /// 18 pt template ring: a faint full circle with the done share drawn
    /// clockwise from 12 o'clock.
    private static func ringImage(fraction: Double) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.5

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 2.2
            NSColor.black.withAlphaComponent(0.3).setStroke()
            track.stroke()

            let done = max(0.03, min(1, fraction))
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius,
                          startAngle: 90, endAngle: 90 - 360 * done, clockwise: true)
            arc.lineWidth = 2.2
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "PicFacet progress"
        return image
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
            idleImage = button.image
            NSLog("[MenuBar] Custom icon created")
        } else {
            // Fallback to SF Symbol
            button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                                   accessibilityDescription: "PicFacet")
            button.image?.isTemplate = true
            idleImage = button.image
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

        // Reused across rebuilds; an item can only belong to one menu.
        progressItem.menu?.removeItem(progressItem)
        progressSeparator.menu?.removeItem(progressSeparator)
        progressItem.isEnabled = false
        progressItem.isHidden = !RunProgress.shared.isRunning
        progressSeparator.isHidden = progressItem.isHidden
        progressItem.title = RunProgress.shared.label
        menu.addItem(progressItem)
        menu.addItem(progressSeparator)
        
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
        BatchWindowController.shared.show()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openOnboarding() {
        OnboardingWindowController.shared.show()
    }

    @objc private func setAppearance(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let appearance = PicFacetSettings.AppAppearance(rawValue: rawValue) else {
            return
        }

        AppearanceController.set(appearance)
        buildMenu()
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
