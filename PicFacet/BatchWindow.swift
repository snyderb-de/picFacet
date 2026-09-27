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

private enum BatchResizeMode: Hashable {
    case none
    case percent(Int)
    case customPercent
    case width
    case height
}

struct BatchView: View {
    @State private var files: [FileItem]
    @State private var isProcessing = false
    @State private var currentProgress = 0
    @State private var isDraggingOver = false
    
    // Multiple operation settings
    @State private var selectedFormat: ImageFormat?
    @State private var selectedResizeMode: BatchResizeMode = .none
    @State private var customPercentText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var selectedDPI: Int?

    private var selectedResize: ResizeOperation? {
        switch selectedResizeMode {
        case .none:
            return nil
        case .percent(let percent):
            return .percent(percent)
        case .customPercent:
            guard let value = positiveInt(customPercentText) else { return nil }
            return .percent(value)
        case .width:
            guard let value = positiveInt(widthText) else { return nil }
            return .width(value)
        case .height:
            guard let value = positiveInt(heightText) else { return nil }
            return .height(value)
        }
    }

    private var resizeInputIsValid: Bool {
        switch selectedResizeMode {
        case .none, .percent:
            return true
        case .customPercent, .width, .height:
            return selectedResize != nil
        }
    }
    
    init(initialFiles: [URL]) {
        _files = State(initialValue: initialFiles.map { FileItem(url: $0) })

        let settings = PicFacetSettings.shared
        _selectedFormat = State(initialValue: settings.defaultFormat)
        _selectedResizeMode = State(initialValue: .percent(Self.validDefaultResize(settings.defaultResizePercent)))
        _selectedDPI = State(initialValue: settings.defaultDPI)
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
                    resetOperationDefaults()
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
                    
                    Picker("", selection: $selectedFormat) {
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
                    
                    Picker("", selection: $selectedResizeMode) {
                        Text("Leave as-is").tag(BatchResizeMode.none)
                        Text("25%").tag(BatchResizeMode.percent(25))
                        Text("50%").tag(BatchResizeMode.percent(50))
                        Text("75%").tag(BatchResizeMode.percent(75))
                        Text("Custom %").tag(BatchResizeMode.customPercent)
                        Text("Set width").tag(BatchResizeMode.width)
                        Text("Set height").tag(BatchResizeMode.height)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .disabled(isProcessing)
                    }

                    if selectedResizeMode == .customPercent {
                        resizeEntryRow(label: "Custom scale", text: $customPercentText, suffix: "%")
                    } else if selectedResizeMode == .width {
                        resizeEntryRow(label: "Target width", text: $widthText, suffix: "px")
                    } else if selectedResizeMode == .height {
                        resizeEntryRow(label: "Target height", text: $heightText, suffix: "px")
                    }
                }
                
                // DPI picker
                HStack {
                    Text("DPI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("", selection: $selectedDPI) {
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
                .disabled(files.isEmpty || (selectedFormat == nil && selectedResize == nil && selectedDPI == nil) || !resizeInputIsValid || isProcessing)
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

        let urls = files.map { $0.url }
        let selection = BatchSelection(format: selectedFormat, resize: selectedResize, dpi: selectedDPI)

        Task {
            let result = await ImageProcessor.process(urls, selection) { done, _ in
                currentProgress = done
            }
            handleCompletion(result)
        }
    }

    private func handleCompletion(_ result: ProcessingResult) {
        isProcessing = false
        
        // Show completion alert
        let alert = NSAlert()
        alert.messageText = "Processing Complete"
        
        var operations: [String] = []
        if selectedFormat != nil { operations.append("converted") }
        if selectedResize != nil { operations.append("resized") }
        if selectedDPI != nil { operations.append("DPI changed") }
        
        let operationsText = operations.joined(separator: ", ")
        alert.informativeText = "Successfully \(operationsText) \(result.succeeded.count) file(s)."
        
        if result.hasErrors {
            alert.informativeText += "\n\(result.failed.count) file(s) failed."
        }
        alert.alertStyle = result.hasErrors ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Clear files
        files.removeAll()
        resetOperationDefaults()
        currentProgress = 0
    }

    private func resizeEntryRow(label: String, text: Binding<String>, suffix: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)
                .frame(width: 96, alignment: .leading)

            TextField("Value", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PFDesign.onSurface)
                .frame(width: 86)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                        .strokeBorder(resizeInputIsValid ? PFDesign.outlineVariant.opacity(0.2) : Color.red.opacity(0.55), lineWidth: 1)
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    text.wrappedValue = digitsOnly(newValue)
                }

            Text(suffix)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)

            Spacer()
        }
        .padding(.leading, 68)
    }

    private func digitsOnly(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(5))
    }

    private func positiveInt(_ value: String) -> Int? {
        guard let int = Int(value), int > 0 else { return nil }
        return int
    }

    private func resetOperationDefaults() {
        let settings = PicFacetSettings.shared
        selectedFormat = settings.defaultFormat
        selectedResizeMode = .percent(Self.validDefaultResize(settings.defaultResizePercent))
        selectedDPI = settings.defaultDPI
        customPercentText = ""
        widthText = ""
        heightText = ""
    }

    private static func validDefaultResize(_ value: Int) -> Int {
        [25, 50, 75].contains(value) ? value : 50
    }
}

// MARK: - File Item

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    var thumbnail: NSImage?
    
    init(url: URL) {
        self.url = url
        self.thumbnail = Self.loadThumbnail(for: url)
    }
    
    private static func loadThumbnail(for url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let size = NSSize(width: 40, height: 40)
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        let aspectRatio = image.size.width / image.size.height
        var drawRect = NSRect(origin: .zero, size: size)
        
        if aspectRatio > 1 {
            // Landscape
            let newHeight = size.width / aspectRatio
            drawRect.origin.y = (size.height - newHeight) / 2
            drawRect.size.height = newHeight
        } else {
            // Portrait
            let newWidth = size.height * aspectRatio
            drawRect.origin.x = (size.width - newWidth) / 2
            drawRect.size.width = newWidth
        }
        
        image.draw(in: drawRect)
        thumbnail.unlockFocus()
        
        return thumbnail
    }
}

// MARK: - File Item Row

struct FileItemRow: View {
    let item: FileItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnail = item.thumbnail {
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
