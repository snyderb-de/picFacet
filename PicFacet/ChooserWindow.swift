import AppKit
import SwiftUI
import PicFacetCore

/// Floating Liquid-Glass picker shown when the user invokes the
/// "PicFacet…" Quick Action. Lists every operation grouped by category
/// and runs the chosen one against the URLs Finder handed us.
final class ChooserWindowController {
    static let shared = ChooserWindowController()

    private var window: NSWindow?

    func show(urls: [URL]) {
        if window == nil {
            let hosting = NSHostingController(rootView: ChooserView(onPick: { [weak self] op in
                self?.run(op: op, urls: urls)
                self?.close()
            }, fileCount: urls.count))
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.title = "PicFacet"
            win.isReleasedWhenClosed = false
            win.level = .floating
            win.center()
            window = win
        } else {
            // Rebuild root view so the new URLs are captured.
            let hosting = NSHostingController(rootView: ChooserView(onPick: { [weak self] op in
                self?.run(op: op, urls: urls)
                self?.close()
            }, fileCount: urls.count))
            window?.contentViewController = hosting
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.orderOut(nil)
    }

    private func run(op: ChooserOp, urls: [URL]) {
        let progress: (Int, Int) -> Void = { d, t in NSLog("[PicFacet] %d/%d", d, t) }
        let complete: (ProcessingResult) -> Void = { r in
            NSLog("[PicFacet] done ok=%d failed=%d", r.succeeded.count, r.failed.count)
        }
        switch op {
        case .convert(let f):
            ImageProcessor.shared.convert(urls, to: f, onProgress: progress, onComplete: complete)
        case .resizePercent(let p):
            ImageProcessor.shared.resize(urls, byPercent: Double(p), onProgress: progress, onComplete: complete)
        case .dpi(let d):
            ImageProcessor.shared.changeDPI(urls, to: d, onProgress: progress, onComplete: complete)
        }
    }
}

// MARK: - Operations

enum ChooserOp: Hashable {
    case convert(ImageFormat)
    case resizePercent(Int)
    case dpi(Int)
}

// MARK: - View

struct ChooserView: View {
    let onPick: (ChooserOp) -> Void
    let fileCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            section("Convert to") {
                ForEach(ImageFormat.allCases, id: \.self) { fmt in
                    chip(fmt.displayName) { onPick(.convert(fmt)) }
                }
            }

            section("Resize") {
                ForEach([10, 25, 50, 75, 90], id: \.self) { p in
                    chip("\(p)%") { onPick(.resizePercent(p)) }
                }
            }

            section("Change DPI") {
                ForEach(PicFacetSettings.dpiOptions, id: \.self) { d in
                    chip("\(d)") { onPick(.dpi(d)) }
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(.clear)
        .glassBackground()
    }

    private var header: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("PicFacet").font(.headline)
                Text("\(fileCount) image\(fileCount == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) { content() }
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Glass background helper (graceful fallback)

private extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.regularMaterial).glassEffect(in: .rect(cornerRadius: 18))
        } else {
            self.background(.regularMaterial)
        }
    }
}

// MARK: - Tiny flow layout (chips wrap to next row)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
