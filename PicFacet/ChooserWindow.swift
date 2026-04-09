import AppKit
import SwiftUI
import PicFacetCore

/// Floating picker shown when the user invokes the "PicFacet…" Quick Action.
/// Styled after the right-hand control card of the Converter Workspace mockup
/// (see mockups/picfacet_converter_light). Lists every operation we currently
/// ship and runs the chosen one against the URLs Finder handed us.
final class ChooserWindowController {
    static let shared = ChooserWindowController()

    private var window: NSWindow?

    func show(urls: [URL]) {
        let root = ChooserView(fileCount: urls.count) { [weak self] op in
            self?.run(op: op, urls: urls)
            self?.close()
        }
        if window == nil {
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.title = "PicFacet"
            win.isReleasedWhenClosed = false
            win.level = .floating
            win.backgroundColor = NSColor(PFDesign.canvas)
            win.center()
            window = win
        } else {
            window?.contentViewController = NSHostingController(rootView: root)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func close() { window?.orderOut(nil) }

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
    let fileCount: Int
    let onPick: (ChooserOp) -> Void

    @State private var selectedFormat: ImageFormat? = nil
    @State private var selectedPercent: Int? = nil
    @State private var dpi: Int = 300

    private let percents = [10, 25, 50, 75, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            PFCard {
                formatSection
                resizeSection
                dpiSection
                startButton
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(PFDesign.canvas)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Converter")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(PFDesign.onSurface)
            Text("\(fileCount) image\(fileCount == 1 ? "" : "s") selected")
                .font(.system(size: 12))
                .foregroundStyle(PFDesign.onSurfaceVariant)
        }
    }

    // MARK: Sections

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PFSectionLabel(text: "Format Selection")
            FlowLayout(spacing: 8) {
                ForEach(ImageFormat.allCases, id: \.self) { fmt in
                    PFChip(
                        title: fmt.displayName,
                        isSelected: selectedFormat == fmt
                    ) {
                        selectedFormat = fmt
                        selectedPercent = nil
                    }
                }
            }
        }
    }

    private var resizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PFSectionLabel(text: "Resize Controls")
            FlowLayout(spacing: 8) {
                ForEach(percents, id: \.self) { p in
                    PFChip(
                        title: "\(p)%",
                        isSelected: selectedPercent == p
                    ) {
                        selectedPercent = p
                        selectedFormat = nil
                    }
                }
            }
        }
    }

    private var dpiSection: some View {
        HStack {
            PFSectionLabel(text: "DPI Settings")
            Spacer()
            Picker("", selection: $dpi) {
                ForEach(PicFacetSettings.dpiOptions, id: \.self) { d in
                    Text("\(d) DPI").tag(d)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(PFDesign.primary)
            .fixedSize()
        }
    }

    private var startButton: some View {
        Button {
            if let f = selectedFormat {
                onPick(.convert(f))
            } else if let p = selectedPercent {
                onPick(.resizePercent(p))
            } else {
                onPick(.dpi(dpi))
            }
        } label: {
            Text("Start Processing")
        }
        .buttonStyle(PFPrimaryButtonStyle())
        .padding(.top, 4)
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
