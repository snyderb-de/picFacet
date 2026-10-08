import AppKit
import SwiftUI
import PicFacetCore

/// Floating picker shown when the user invokes the "PicFacet…" Quick Action.
final class ChooserWindowController {
    static let shared = ChooserWindowController()

    private var window: NSWindow?

    /// `selection` pre-fills the options, e.g. from a recipe; nil uses the defaults.
    func show(urls: [URL], selection: BatchSelection? = nil) {
        let root = ChooserView(urls: urls, initialSelection: selection) { [weak self] in
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
    static let minSize = NSSize(width: 960, height: 660)
    static let idealSize = NSSize(width: 1000, height: 700)

    let urls: [URL]
    /// Closes the window: on Cancel, or after a run and its alert.
    let onClose: () -> Void

    @State private var draft: OperationDraft

    init(urls: [URL], initialSelection: BatchSelection? = nil, onClose: @escaping () -> Void) {
        self.urls = urls
        self.onClose = onClose
        _draft = State(initialValue: initialSelection.map(OperationDraft.init(selection:)) ?? .defaults())
    }
    @State private var summary = QueueSummary()
    @State private var runStats = RunStats()
    /// (completed, total) while a run is in progress.
    @State private var progress: (completed: Int, total: Int)?

    var fileCount: Int { urls.count }

    private var canStart: Bool { draft.selection != nil }

    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 18) {
                rootContent
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 22)

            PFStatusBar(status: "\(fileCount) image\(fileCount == 1 ? "" : "s") · \(summary.sizeText)")
        }
        .frame(
            minWidth: Self.minSize.width,
            idealWidth: Self.idealSize.width,
            maxWidth: .infinity,
            minHeight: Self.minSize.height,
            idealHeight: Self.idealSize.height,
            maxHeight: .infinity
        )
        .background { PFDesign.backdrop }
        .task(id: urls) { summary = await QueueSummary.load(urls) }
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
                .frame(maxHeight: .infinity, alignment: .top)
                .pfPanel()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    // MARK: - Thumbnails
    
    private var selectedFilesPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Image Queue")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                Text(isRunning ? "Processing…" : "\(fileCount) image\(fileCount == 1 ? "" : "s") ready")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            statsGrid

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(urls, id: \.self) { url in
                        ImageQueueRow(url: url)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(18)
        .pfContentPanel()
    }

    /// Queue totals while idle; running totals while a batch is processing.
    private var statsGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            if isRunning {
                GridRow {
                    PFStatPill(icon: "checkmark.circle", title: "Done", value: runStats.doneText)
                    PFStatPill(icon: "arrow.down.circle", title: runStats.savedTitle, value: runStats.savedText)
                }
                GridRow {
                    PFStatPill(icon: "equal.circle", title: "Kept", value: "\(runStats.kept)")
                    PFStatPill(icon: "exclamationmark.circle", title: "Failed", value: "\(runStats.failed)")
                }
            } else {
                GridRow {
                    PFStatPill(icon: "photo.stack", title: "Images", value: "\(fileCount)")
                    PFStatPill(icon: "externaldrive", title: "Size", value: summary.sizeText)
                }
                GridRow {
                    PFStatPill(icon: "doc.on.doc", title: "Formats", value: summary.formatsText)
                        .help(summary.formatsDetail)
                    PFStatPill(icon: "square.resize", title: "Pixels", value: summary.megapixelsText)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        Text("PicFacet")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(PFDesign.onSurface)
    }

    // MARK: Sections

    private var operationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PFSectionLabel(text: "Processing Options")
                Spacer()
                RecipeMenu(draft: $draft)
                    .disabled(isRunning)
            }

            ScrollView {
                OperationMenus(draft: $draft, labelWidth: 170, menuWidth: 220, showsDetails: true)
                    .disabled(isRunning)
                    .padding(.trailing, 4)
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: .infinity)
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
        runStats = RunStats(total: urls.count)

        let tracked = RunProgress.shared.begin(total: urls.count)

        Task {
            let result = await ImageProcessor.process(urls, selection, policy: policy) { p in
                progress = (p.completed, p.total)
                runStats.add(p.latest)
                RunProgress.shared.update(tracked, completed: p.completed)
            }
            RunProgress.shared.end(tracked)
            NSLog("[PicFacet] done ok=%d kept=%d failed=%d",
                  result.succeeded.count, result.keptOriginal.count, result.failed.count)
            try? await Task.sleep(for: .milliseconds(700))  // let the fill land
            CompletionAlert.show(result, summary: summary)
            onClose()
        }
    }
}
