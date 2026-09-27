import AppKit
import SwiftUI
import PicFacetCore

/// Floating picker shown when the user invokes the "PicFacet…" Quick Action.
final class ChooserWindowController {
    static let shared = ChooserWindowController()

    private var window: NSWindow?

    func show(urls: [URL]) {
        let root = ChooserView(urls: urls, onCancel: { [weak self] in
            self?.close()
        }) { [weak self] draft in
            self?.run(draft: draft, urls: urls)
            self?.close()
        }
        if window == nil {
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.title = "PicFacet"
            win.isReleasedWhenClosed = false
            win.level = .floating
            win.backgroundColor = NSColor(PFDesign.canvas)
            win.setContentSize(NSSize(width: 980, height: 700))
            win.minSize = NSSize(width: 900, height: 640)
            win.center()
            window = win
        } else {
            window?.contentViewController = NSHostingController(rootView: root)
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func close() { window?.orderOut(nil) }

    private func run(draft: OperationDraft, urls: [URL]) {
        guard let selection = draft.selection else { return }
        let policy = PicFacetSettings.shared.outputPolicy

        Task {
            let r = await ImageProcessor.process(urls, selection, policy: policy) { d, t in
                NSLog("[PicFacet] %d/%d", d, t)
            }
            NSLog("[PicFacet] done ok=%d failed=%d", r.succeeded.count, r.failed.count)
            CompletionAlert.show(r, summary: draft.summary)
        }
    }
}

// MARK: - View

struct ChooserView: View {
    let urls: [URL]
    let onCancel: () -> Void
    let onPick: (OperationDraft) -> Void

    @State private var draft = OperationDraft.defaults()
    @State private var thumbnails: [URL: NSImage] = [:]

    init(urls: [URL], onCancel: @escaping () -> Void, onPick: @escaping (OperationDraft) -> Void) {
        self.urls = urls
        self.onCancel = onCancel
        self.onPick = onPick
    }

    var fileCount: Int { urls.count }

    private var loadedThumbnail: NSImage? {
        urls.lazy.compactMap { thumbnails[$0] }.first
    }

    private var formatSummary: String {
        let formats = Set(urls.map { $0.pathExtension.uppercased() }.filter { !$0.isEmpty })
        if formats.isEmpty { return "Images" }
        if formats.count == 1, let format = formats.first { return format }
        return "\(formats.count) formats"
    }

    private var totalSizeSummary: String {
        let total = urls.reduce(Int64(0)) { partial, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return partial + size
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var hasSelection: Bool { draft.format != nil || draft.resize != nil || draft.dpi != nil }
    private var canStart: Bool { draft.selection != nil }

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            rootContent
        }
        .padding(30)
        .frame(
            minWidth: 900,
            idealWidth: 980,
            maxWidth: .infinity,
            minHeight: 640,
            idealHeight: 700,
            maxHeight: .infinity
        )
        .background {
            ZStack {
                PFDesign.canvas
                LinearGradient(
                    colors: [
                        PFDesign.primary.opacity(0.10),
                        PFDesign.success.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .onAppear {
            loadThumbnails()
        }
    }

    private var rootContent: some View {
        HStack(alignment: .top, spacing: 22) {
            selectedFilesPanel
                .frame(width: 300)

            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    operationSection
                    summaryBar
                    actionBar
                }
                .padding(22)
                .pfPanel()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Thumbnails
    
    private var selectedFilesPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Source Set")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                Text("\(fileCount) image\(fileCount == 1 ? "" : "s") selected")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            heroPreview

            HStack(spacing: 8) {
                PFStatPill(icon: "photo.stack", title: "Type", value: formatSummary)
                PFStatPill(icon: "externaldrive", title: "Size", value: totalSizeSummary)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(urls.prefix(12), id: \.self) { url in
                        filePreviewRow(for: url)
                    }
                    if urls.count > 12 {
                        Text("+ \(urls.count - 12) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PFDesign.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(18)
        .pfPanel()
    }

    private var heroPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PFDesign.surfaceLow)

            if let thumbnail = loadedThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .saturation(1.04)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(PFDesign.onSurfaceVariant.opacity(0.48))
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PFDesign.success)
                Text("Ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(PFDesign.chrome, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(10)
        }
        .frame(height: 178)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PFDesign.outlineVariant.opacity(0.2), lineWidth: 1)
        }
    }

    private func filePreviewRow(for url: URL) -> some View {
        HStack(spacing: 10) {
            if let thumbnail = thumbnails[url] {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(PFDesign.outlineVariant.opacity(0.2), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(PFDesign.surfaceLow)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(PFDesign.onSurfaceVariant.opacity(0.5))
                    }
            }

            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurface)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PFDesign.outlineVariant.opacity(0.12), lineWidth: 1)
        }
    }
    
    private func loadThumbnails() {
        for url in urls.prefix(12) {
            Task {
                thumbnails[url] = await Thumbnail.load(url, maxPixelSize: 840)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("PicFacet")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)

                Text("Production-ready image prep")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(fileCount)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(PFDesign.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PFDesign.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: Sections

    private var operationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PFSectionLabel(text: "Processing Options")
                Spacer()
                Text("Format -> Resize -> DPI")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: 9) {
                optionLabel("Format", detail: "Output file type")
                FlowLayout(spacing: 8) {
                    PFChip(title: "Leave as-is", isSelected: draft.format == nil) {
                        draft.format = nil
                    }
                    ForEach(ImageFormat.allCases, id: \.self) { fmt in
                        PFChip(title: fmt.displayName, isSelected: draft.format == fmt, systemImage: formatIcon(for: fmt)) {
                            draft.format = fmt
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                optionLabel("Resize", detail: "Scale or constrain dimensions")
                FlowLayout(spacing: 8) {
                    ForEach(ResizeMode.allCases, id: \.self) { mode in
                        PFChip(title: mode.title, isSelected: draft.resizeMode == mode, systemImage: mode.systemImage) {
                            draft.resizeMode = mode
                        }
                    }
                }

                ResizeEntryRow(draft: $draft)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 9) {
                optionLabel("DPI", detail: "Print-resolution metadata")
                FlowLayout(spacing: 8) {
                    PFChip(title: "Leave as-is", isSelected: draft.dpi == nil) {
                        draft.dpi = nil
                    }
                    ForEach(PicFacetSettings.dpiOptions, id: \.self) { d in
                        PFChip(title: "\(d)", isSelected: draft.dpi == d, systemImage: dpiIcon(for: d)) {
                            draft.dpi = d
                        }
                    }
                }
            }
        }
    }

    private func optionLabel(_ title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PFDesign.onSurface)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(PFDesign.onSurfaceVariant)
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 10) {
            Image(systemName: canStart ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canStart ? PFDesign.success : PFDesign.onSurfaceVariant)
            Text(draft.summary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hasSelection ? PFDesign.onSurface : PFDesign.onSurfaceVariant)
                .lineLimit(2)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder((canStart ? PFDesign.success : PFDesign.outlineVariant).opacity(0.18), lineWidth: 1)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .pfSecondaryActionStyle()

            Button {
                onPick(draft)
            } label: {
                Label("Start Processing", systemImage: "sparkles")
            }
            .pfPrimaryActionStyle()
            .disabled(!canStart)
        }
        .padding(.top, 4)
    }

    private func formatIcon(for format: ImageFormat) -> String {
        switch format {
        case .jpeg, .png, .heic, .webp: return "photo"
        case .tiff, .bmp: return "doc.richtext"
        case .gif: return "play.rectangle"
        }
    }

    private func dpiIcon(for dpi: Int) -> String {
        dpi >= 600 ? "printer.filled.and.paper" : "printer"
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
