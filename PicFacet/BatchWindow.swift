import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PicFacetCore

/// Batch window: drag & drop zone, file list with thumbnails,
/// and live progress during processing operations.
final class BatchWindowController {
    static let shared = BatchWindowController()
    
    private var window: NSWindow?
    private var hostingController: NSHostingController<BatchView>?
    
    private init() {}
    
    func show(with files: [URL] = []) {
        let view = BatchView(initialFiles: files)
        
        if window == nil {
            hostingController = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hostingController!)
            win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.title = "PicFacet Processing"
            win.isReleasedWhenClosed = false
            win.backgroundColor = .windowBackgroundColor
            win.setContentSize(NSSize(width: 880, height: 720))
            win.minSize = NSSize(width: 780, height: 640)
            win.center()
            window = win
        } else {
            hostingController?.rootView = view
        }
        
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
    
    func close() {
        window?.orderOut(nil)
    }
}

// MARK: - SwiftUI View

struct BatchView: View {
    @State private var files: [FileItem]
    @State private var isProcessing = false
    @State private var currentProgress = 0
    @State private var isDraggingOver = false
    
    @State private var draft = OperationDraft.defaults()
    @State private var activity: [ActivityRun] = []

    init(initialFiles: [URL]) {
        _files = State(initialValue: initialFiles.map { FileItem(url: $0) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 22) {
                rootContent
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 22)

            PFStatusBar(status: files.isEmpty ? "" : "\(files.count) image\(files.count == 1 ? "" : "s")")
        }
        .frame(
            minWidth: 780,
            idealWidth: 880,
            maxWidth: .infinity,
            minHeight: 640,
            idealHeight: 720,
            maxHeight: .infinity
        )
        .background { PFDesign.backdrop }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
    }

    private var rootContent: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(spacing: 18) {
                headerView

                if files.isEmpty {
                    dropZoneView
                } else {
                    fileListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 22) {
                controlsView
                ActivityLogView(runs: activity) { activity.removeAll() }
                    .padding(22)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .pfPanel()
            }
            .frame(width: 310)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Batch Processor")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)

                Text(isProcessing ? "Processing..." : files.isEmpty ? "Drop images to begin" : "Ready to process")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }

            Spacer()

            if !files.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: isProcessing ? "gearshape.2.fill" : "photo.stack")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(files.count)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PFDesign.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PFDesign.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    // MARK: - Drop Zone
    
    private var dropZoneView: some View {
        VStack(spacing: 18) {
            Spacer()
            
            Image(systemName: isDraggingOver ? "photo.badge.plus.fill" : "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(isDraggingOver ? PFDesign.primary : PFDesign.onSurfaceVariant.opacity(0.4))
                .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
            
            VStack(spacing: 8) {
                Text("Drop Images Here")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                
                Text("Or click below to select files")
                    .font(.system(size: 13))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
            }
            
            Button("Select Files…") {
                selectFiles()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(PFDesign.primary)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: PFDesign.rPanel, style: .continuous)
                .fill(isDraggingOver ? PFDesign.primary.opacity(0.08) : PFDesign.surfaceLowest.opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: PFDesign.rPanel, style: .continuous)
                .strokeBorder(
                    isDraggingOver ? PFDesign.primary : PFDesign.outlineVariant.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
    }
    
    // MARK: - File List
    
    private var fileListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("Image Queue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                Button {
                    files.removeAll()
                    draft = .defaults()
                    isProcessing = false
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PFDesign.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
            
            // Scrollable file list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(files) { file in
                        ImageQueueRow(url: file.url)
                    }
                }
            }

        }
        .padding(18)
        .pfContentPanel()
    }
    
    // MARK: - Controls
    
    private var controlsView: some View {
        PFCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    PFSectionLabel(text: "Processing Options")
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PFDesign.primary)
                }
                
                OperationMenus(draft: $draft)
                    .disabled(isProcessing)

                PFRunBar(
                    summary: draft.summary,
                    isReady: draft.selection != nil,
                    progress: isProcessing ? (currentProgress, files.count) : nil
                )

                // Start button
                Button {
                    startProcessing()
                } label: {
                    Label(isProcessing ? "Processing..." : "Start Processing", systemImage: "sparkles")
                }
                .pfPrimaryActionStyle()
                .disabled(files.isEmpty || draft.selection == nil || isProcessing)
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select images to process"
        
        panel.begin { response in
            if response == .OK {
                let newFiles = panel.urls.map { FileItem(url: $0) }
                files.append(contentsOf: newFiles)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, !url.hasDirectoryPath, url.isImageFile else { return }
                Task { @MainActor in
                    files.append(FileItem(url: url))
                }
            }
        }
        return true
    }
    
    private func startProcessing() {
        isProcessing = true
        currentProgress = 0

        guard let selection = draft.selection else { return }
        let summary = draft.summary
        let policy = PicFacetSettings.shared.outputPolicy
        let urls = files.map { $0.url }

        let run = ActivityRun(summary: selection.summary)
        activity.insert(run, at: 0)

        Task {
            let result = await ImageProcessor.process(urls, selection, policy: policy) { progress in
                currentProgress = progress.completed
                // Looked up by id: the log may have been cleared mid-run.
                if let index = activity.firstIndex(where: { $0.id == run.id }) {
                    activity[index].reports.insert(progress.latest, at: 0)
                }
            }
            try? await Task.sleep(for: .milliseconds(700))  // let the fill land
            handleCompletion(result, summary: summary)
        }
    }

    private func handleCompletion(_ result: ProcessingResult, summary: String) {
        isProcessing = false
        CompletionAlert.show(result, summary: summary)

        files.removeAll()
        draft = .defaults()
        currentProgress = 0
    }
}

// MARK: - File Item

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Previews

#Preview("Empty State") {
    BatchView(initialFiles: [])
        .frame(width: 520, height: 640)
}

#Preview("With Files") {
    BatchView(initialFiles: [
        URL(fileURLWithPath: "/Users/demo/image1.jpg"),
        URL(fileURLWithPath: "/Users/demo/image2.png"),
        URL(fileURLWithPath: "/Users/demo/photo.heic")
    ])
    .frame(width: 520, height: 640)
}
