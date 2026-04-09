import AppKit
import SwiftUI

/// First-launch window that explains how to enable PicFacet's Quick Actions
/// in System Settings. Reachable any time from the menu bar.
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private static let seenKey = "picfacet.onboardingShown"

    func showIfFirstLaunch() {
        if !UserDefaults.standard.bool(forKey: Self.seenKey) {
            UserDefaults.standard.set(true, forKey: Self.seenKey)
            show()
        }
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: OnboardingView(onClose: { [weak self] in
                self?.window?.orderOut(nil)
            }))
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.title = "Welcome to PicFacet"
            win.isReleasedWhenClosed = false
            win.backgroundColor = NSColor(PFDesign.canvas)
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct OnboardingView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to PicFacet")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(PFDesign.onSurface)
                Text("Right-click image actions, the easy way.")
                    .font(.system(size: 13))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            PFCard {
                PFSectionLabel(text: "Enable Quick Actions")
                Text("""
PicFacet ships every action turned **off** so your right-click menu stays clean. Pick the ones you want:

1. Open **System Settings → Keyboard → Keyboard Shortcuts → Services**.
2. Expand **Files and Folders** (and **Pictures**).
3. Tick the PicFacet items you want — e.g. *PicFacet…*, *PicFacet: Convert to JPEG*, *PicFacet: Resize 50%*.
4. Right-click any image in Finder. Your enabled actions appear under **Quick Actions**.

Tip: enable **PicFacet…** to get the full picker (every format, every preset) in one click.
""")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            HStack(spacing: 12) {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Services") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(PFSecondaryButtonStyle())

                Button("Got it", action: onClose)
                    .buttonStyle(PFPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 560)
        .background(PFDesign.canvas)
    }
}
