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
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32))
                VStack(alignment: .leading) {
                    Text("Welcome to PicFacet").font(.title2.weight(.semibold))
                    Text("Right-click image actions, the easy way.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Enable Quick Actions")
                .font(.headline)

            Text("""
PicFacet ships every action turned **off** so your right-click menu stays clean. Pick the ones you want:

1. Open **System Settings → Keyboard → Keyboard Shortcuts → Services**.
2. Expand **Files and Folders** (and **Pictures**).
3. Tick the PicFacet items you want — e.g. *PicFacet…*, *PicFacet: Convert to JPEG*, *PicFacet: Resize 50%*.
4. Right-click any image in Finder. Your enabled actions appear under **Quick Actions**.

Tip: enable **PicFacet…** to get the full picker (every format, every preset) in one click.
""")
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Services") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.glass)

                Spacer()

                Button("Got it", action: onClose)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .background(.regularMaterial)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
