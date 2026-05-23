import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Progress window that shows drag & drop zone, file list with thumbnails,
/// and live progress during processing operations.
///
/// NOTE: This file should be moved to the main app target (not PicFacetCore)
/// so it can access PFDesign and other design system components.
/// For now, it includes minimal design tokens to work standalone.
public final class ProgressWindowController {
    public static let shared = ProgressWindowController()
    
    private var window: NSWindow?
    private var hostingController: NSHostingController<ProgressView>?
    
    private init() {}
    
    public func show(with files: [URL] = []) {
        let view = ProgressView(initialFiles: files)
        
        if window == nil {
            hostingController = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hostingController!)
            win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.title = "PicFacet Processing"
            win.isReleasedWhenClosed = false
            win.level = .floating
            win.backgroundColor = NSColor(red: 0.976, green: 0.976, blue: 0.984, alpha: 1.0)
            win.setContentSize(NSSize(width: 520, height: 640))
            win.center()
            window = win
        } else {
            hostingController?.rootView = view
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    public func close() {
        window?.orderOut(nil)
    }
}

// MARK: - Minimal Design Tokens (until moved to main app)

private enum ProgressDesign {
    static let canvas = Color(red: 0.976, green: 0.976, blue: 0.984)
    static let surface = Color.white
    static let surfaceLow = Color(red: 0.953, green: 0.953, blue: 0.961)
    static let surfaceHigh = Color(red: 0.910, green: 0.910, blue: 0.918)
    
    static let onSurface = Color(red: 0.102, green: 0.110, blue: 0.114)
    static let onSurfaceVariant = Color(red: 0.369, green: 0.384, blue: 0.447)
    static let outlineVariant = Color(red: 0.757, green: 0.776, blue: 0.843)
    
    static let primary = Color(red: 0.0, green: 0.345, blue: 0.737)
    static let primaryBright = Color(red: 0.0, green: 0.439, blue: 0.922)
    
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - SwiftUI View

struct ProgressView: View {
    @State private var files: [FileItem]
    @State private var isProcessing = false
    @State private var currentProgress = 0
    @State private var isDraggingOver = false
    
    // Multiple operation settings
    @State private var selectedFormat: ImageFormat? = nil
    @State private var selectedResize: Int? = nil
    @State private var selectedDPI: Int? = nil
    
    init(initialFiles: [URL]) {
        _files = State(initialValue: initialFiles.map { FileItem(url: $0) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            // Main content area
            if files.isEmpty {
                dropZoneView
            } else {
                fileListView
            }
            
            // Bottom controls
            controlsView
                .padding(24)
        }
        .background(ProgressDesign.canvas)
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Batch Processor")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(ProgressDesign.onSurface)
                
                if !files.isEmpty {
                    Text("\(files.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ProgressDesign.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ProgressDesign.primary.opacity(0.12), in: Capsule())
                }
            }
            
            if isProcessing {
                Text("Processing…")
                    .font(.system(size: 12))
                    .foregroundStyle(ProgressDesign.primary)
            } else if !files.isEmpty {
                Text("Ready to process")
                    .font(.system(size: 12))
                    .foregroundStyle(ProgressDesign.onSurfaceVariant)
            }
        }
    }
    
    // MARK: - Drop Zone
    
    private var dropZoneView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: isDraggingOver ? "photo.badge.plus.fill" : "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(isDraggingOver ? ProgressDesign.primary : ProgressDesign.onSurfaceVariant.opacity(0.4))
                .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
            
            VStack(spacing: 8) {
                Text("Drop Images Here")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ProgressDesign.onSurface)
                
                Text("Or click below to select files")
                    .font(.system(size: 13))
                    .foregroundStyle(ProgressDesign.onSurfaceVariant)
            }
            
            Button("Select Files…") {
                selectFiles()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isDraggingOver ? ProgressDesign.primary : ProgressDesign.outlineVariant.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isDraggingOver ? ProgressDesign.primary.opacity(0.05) : Color.clear)
                )
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
    }
    
    // MARK: - File List
    
    private var fileListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("Files")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ProgressDesign.onSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                Button {
                    files.removeAll()
                    selectedFormat = nil
                    selectedResize = nil
                    selectedDPI = nil
                    isProcessing = false
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ProgressDesign.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Scrollable file list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(files) { file in
                        FileItemRow(item: file)
                    }
                }
                .padding(.horizontal, 24)
            }
            
            // Progress indicator (when processing)
            if isProcessing {
                ProgressIndicatorView(current: currentProgress, total: files.count)
                    .padding(24)
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Processing Options")
                
                // Format picker
                HStack {
                    Text("Format")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProgressDesign.onSurfaceVariant)
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
                HStack {
                    Text("Resize")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProgressDesign.onSurfaceVariant)
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("", selection: $selectedResize) {
                        Text("Leave as-is").tag(nil as Int?)
                        Text("10%").tag(Optional(10))
                        Text("25%").tag(Optional(25))
                        Text("50%").tag(Optional(50))
                        Text("75%").tag(Optional(75))
                        Text("90%").tag(Optional(90))
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .disabled(isProcessing)
                }
                
                // DPI picker
                HStack {
                    Text("DPI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProgressDesign.onSurfaceVariant)
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
                    Text(isProcessing ? "Processing…" : "Start Processing")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(files.isEmpty || (selectedFormat == nil && selectedResize == nil && selectedDPI == nil) || isProcessing)
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
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.hasDirectoryPath == false {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let newFiles = urls.map { FileItem(url: $0) }
            files.append(contentsOf: newFiles)
        }
        
        return true
    }
    
    private func startProcessing() {
        isProcessing = true
        currentProgress = 0
        
        let urls = files.map { $0.url }
        
        // Process files with selected operations (can be multiple!)
        processFiles(urls: urls, format: selectedFormat, resize: selectedResize, dpi: selectedDPI)
    }
    
    private func processFiles(urls: [URL], format: ImageFormat?, resize: Int?, dpi: Int?) {
        // For now, we'll process them sequentially
        // Format conversion first, then resize, then DPI
        
        if let format = format {
            ImageProcessor.shared.convert(urls, to: format) { done, total in
                currentProgress = done
            } onComplete: { result in
                if let resize = resize {
                    // Continue with resize on the converted files
                    let nextURLs = result.succeeded
                    self.processResize(urls: nextURLs, percent: resize, dpi: dpi)
                } else if let dpi = dpi {
                    // Continue with DPI on the converted files
                    let nextURLs = result.succeeded
                    self.processDPI(urls: nextURLs, dpi: dpi)
                } else {
                    // Done!
                    self.handleCompletion(result)
                }
            }
        } else if let resize = resize {
            processResize(urls: urls, percent: resize, dpi: dpi)
        } else if let dpi = dpi {
            processDPI(urls: urls, dpi: dpi)
        }
    }
    
    private func processResize(urls: [URL], percent: Int, dpi: Int?) {
        ImageProcessor.shared.resize(urls, byPercent: Double(percent)) { done, total in
            currentProgress = done
        } onComplete: { result in
            if let dpi = dpi {
                // Continue with DPI
                let nextURLs = result.succeeded
                self.processDPI(urls: nextURLs, dpi: dpi)
            } else {
                // Done!
                self.handleCompletion(result)
            }
        }
    }
    
    private func processDPI(urls: [URL], dpi: Int) {
        ImageProcessor.shared.changeDPI(urls, to: dpi) { done, total in
            currentProgress = done
        } onComplete: { result in
            // Done!
            self.handleCompletion(result)
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
        selectedFormat = nil
        selectedResize = nil
        selectedDPI = nil
        currentProgress = 0
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
                            .strokeBorder(ProgressDesign.outlineVariant.opacity(0.2), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ProgressDesign.surfaceLow)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundStyle(ProgressDesign.onSurfaceVariant.opacity(0.5))
                    }
            }
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ProgressDesign.onSurface)
                    .lineLimit(1)
                
                if let fileSize = try? item.url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundStyle(ProgressDesign.onSurfaceVariant)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(ProgressDesign.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ProgressDesign.outlineVariant.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Operation Type

enum Operation {
    case convert(ImageFormat)
    case resize(Int)
    case dpi(Int)
    
    var displayName: String {
        switch self {
        case .convert(let format):
            return "Convert to \(format.displayName)"
        case .resize(let percent):
            return "Resize to \(percent)%"
        case .dpi(let dpi):
            return "Set DPI to \(dpi)"
        }
    }
}

// MARK: - Design Components (minimal, standalone versions)

private struct CardView<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(22)
            .background(ProgressDesign.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(ProgressDesign.outlineVariant.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: ProgressDesign.onSurface.opacity(0.05), radius: 30, x: 0, y: 8)
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(ProgressDesign.onSurfaceVariant)
    }
}

private struct ProgressIndicatorView: View {
    let current: Int
    let total: Int
    
    var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(ProgressDesign.surfaceLow)
                        .frame(height: 6)
                    
                    Capsule(style: .continuous)
                        .fill(ProgressDesign.primaryGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("Processing images…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ProgressDesign.onSurfaceVariant)
                Spacer()
                Text("\(current) of \(total)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ProgressDesign.primary)
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ProgressDesign.primaryGradient, in: Capsule(style: .continuous))
            .shadow(color: ProgressDesign.primary.opacity(0.25), radius: 14, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ProgressDesign.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ProgressDesign.surfaceHigh, in: Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    ProgressView(initialFiles: [])
        .frame(width: 520, height: 640)
}

#Preview("With Files") {
    ProgressView(initialFiles: [
        URL(fileURLWithPath: "/Users/demo/image1.jpg"),
        URL(fileURLWithPath: "/Users/demo/image2.png"),
        URL(fileURLWithPath: "/Users/demo/photo.heic")
    ])
    .frame(width: 520, height: 640)
}

