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
            win.level = .floating
            win.backgroundColor = .windowBackgroundColor
            win.setContentSize(NSSize(width: 880, height: 680))
            win.minSize = NSSize(width: 780, height: 600)
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

    init(initialFiles: [URL]) {
        _files = State(initialValue: initialFiles.map { FileItem(url: $0) })
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 22) {
            rootContent
        }
        .padding(30)
        .frame(
            minWidth: 780,
            idealWidth: 880,
            maxWidth: .infinity,
            minHeight: 600,
            idealHeight: 680,
            maxHeight: .infinity
        )
        .background {
            ZStack {
                PFDesign.canvas
                LinearGradient(
                    colors: [
                        PFDesign.primary.opacity(0.10),
                        PFDesign.success.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
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

            controlsView
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
            
            Button("Select Files...") {
                selectFiles()
            }
            .pfSecondaryActionStyle()
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isDraggingOver ? PFDesign.primary : PFDesign.outlineVariant.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isDraggingOver ? PFDesign.primary.opacity(0.05) : Color.clear)
                )
        }
        .pfPanel()
        .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
    }
    
    // MARK: - File List
    
    private var fileListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("Files")
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
                        FileItemRow(item: file)
                    }
                }
            }
            
            // Progress indicator (when processing)
            if isProcessing {
                PFProgressView(current: currentProgress, total: files.count)
                    .padding(.top, 14)
            }
        }
        .padding(18)
        .pfPanel()
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
                
                // Format picker
                HStack {
                    Text("Format")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("", selection: $draft.format) {
                        Text("Leave as-is").tag(nil as ImageFormat?)
                        ForEach(ImageFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(Optional(format))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .disabled(isProcessing)
                }
                
                // Resize picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                    Text("Resize")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("", selection: $draft.resizeMode) {
                        ForEach(ResizeMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .disabled(isProcessing)
                    }

                    ResizeEntryRow(draft: $draft, labelWidth: 96)
                        .padding(.leading, 68)
                }
                
                // DPI picker
                HStack {
                    Text("DPI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("", selection: $draft.dpi) {
                        Text("Leave as-is").tag(nil as Int?)
                        ForEach(PicFacetSettings.dpiOptions, id: \.self) { dpi in
                            Text("\(dpi) DPI").tag(Optional(dpi))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .disabled(isProcessing)
                }
                
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
                guard let url, !url.hasDirectoryPath else { return }
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

        Task {
            let result = await ImageProcessor.process(urls, selection, policy: policy) { done, _ in
                currentProgress = done
            }
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

// MARK: - File Item Row

struct FileItemRow: View {
    let item: FileItem
    @State private var thumbnail: NSImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(PFDesign.outlineVariant.opacity(0.2), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(PFDesign.surfaceLow)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundStyle(PFDesign.onSurfaceVariant.opacity(0.5))
                    }
            }
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PFDesign.onSurface)
                    .lineLimit(1)
                
                if let fileSize = try? item.url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .modifier(RowBackgroundModifier())
        .task(id: item.url) {
            thumbnail = await Thumbnail.load(item.url, maxPixelSize: 80)
        }
    }
}

private struct RowBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(PFDesign.outlineVariant.opacity(0.1), lineWidth: 1)
            }
    }
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
