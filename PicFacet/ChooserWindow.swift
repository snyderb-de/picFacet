import AppKit
import SwiftUI
import PicFacetCore

/// Floating picker shown when the user invokes the "PicFacet…" Quick Action.
final class ChooserWindowController {
    static let shared = ChooserWindowController()

    private var window: NSWindow?

    func show(urls: [URL]) {
        let root = ChooserView(urls: urls) { [weak self] in
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
            win.setContentSize(ChooserView.idealSize)
            win.contentMinSize = ChooserView.minSize
            win.center()
            window = win
        } else {
            window?.contentViewController = NSHostingController(rootView: root)
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func close() { window?.orderOut(nil) }
}

// MARK: - View

struct ChooserView: View {
    /// Outer padding 30×2 + files panel 300 + gap 22 + options panel (~560).
    /// Anything narrower clips the files panel and overlaps the options.
    static let minSize = NSSize(width: 960, height: 620)
    static let idealSize = NSSize(width: 1000, height: 660)

    let urls: [URL]
    /// Closes the window: on Cancel, or after a run and its alert.
    let onClose: () -> Void

    @State private var draft = OperationDraft.defaults()
    @State private var thumbnails: [URL: NSImage] = [:]
    /// (completed, total) while a run is in progress.
    @State private var progress: (completed: Int, total: Int)?

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

    private var canStart: Bool { draft.selection != nil }

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            rootContent
        }
        .padding(30)
        .frame(
            minWidth: Self.minSize.width,
            idealWidth: Self.idealSize.width,
            maxWidth: .infinity,
            minHeight: Self.minSize.height,
            idealHeight: Self.idealSize.height,
            maxHeight: .infinity
        )
        .background { PFDesign.backdrop }
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .pfContentPanel()
    }

    private var heroPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PFDesign.surfaceLow)

            if let thumbnail = loadedThumbnail {
                // Overlay on a clear shape so the image's own size can't
                // widen the panel (an .aspectRatio(.fill) image would).
                Color.clear
                    .overlay {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .saturation(1.04)
                    }
                    .clipped()
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
                Text("Format → Resize → DPI")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            OperationMenus(draft: $draft, labelWidth: 170, menuWidth: 220, showsDetails: true)
                .disabled(isRunning)
        }
    }

    private var isRunning: Bool { progress != nil }

    private var summaryBar: some View {
        PFRunBar(summary: draft.summary, isReady: canStart, progress: progress)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onClose)
                .pfSecondaryActionStyle()
                .disabled(isRunning)

            Button {
                start()
            } label: {
                Label(isRunning ? "Processing…" : "Start Processing", systemImage: "sparkles")
            }
            .pfPrimaryActionStyle()
            .disabled(!canStart || isRunning)
        }
        .padding(.top, 4)
    }

    private func start() {
        guard let selection = draft.selection else { return }
        let summary = draft.summary
        let policy = PicFacetSettings.shared.outputPolicy
        progress = (0, urls.count)

        Task {
            let result = await ImageProcessor.process(urls, selection, policy: policy) { p in
                progress = (p.completed, p.total)
            }
            NSLog("[PicFacet] done ok=%d kept=%d failed=%d",
                  result.succeeded.count, result.keptOriginal.count, result.failed.count)
            try? await Task.sleep(for: .milliseconds(700))  // let the fill land
            CompletionAlert.show(result, summary: summary)
            onClose()
        }
    }
}
