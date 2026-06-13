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
            win.backgroundColor = .windowBackgroundColor
            win.setContentSize(NSSize(width: 880, height: 680))
            win.minSize = NSSize(width: 780, height: 600)
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
    static let canvas = Color.adaptive(light: 0xF6F7F9, dark: 0x111418)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x242A32)
    static let surfaceLow = Color.adaptive(light: 0xECEFF3, dark: 0x1B2026)
    static let surfaceHigh = Color.adaptive(light: 0xDDE3EA, dark: 0x303842)
    static let chrome = Color.adaptive(light: 0xFBFCFE, dark: 0x181D23, alpha: 0.86)
    
    static let onSurface = Color.adaptive(light: 0x161A1F, dark: 0xF5F7FA)
    static let onSurfaceVariant = Color.adaptive(light: 0x5D6673, dark: 0xB7C0CC)
    static let outlineVariant = Color.adaptive(light: 0xBCC6D2, dark: 0x485360)
    
    static let primary = Color.adaptive(light: 0x005BBF, dark: 0x5AA9FF)
    static let primaryBright = Color.adaptive(light: 0x0078FF, dark: 0x8ECBFF)
    static let success = Color.adaptive(light: 0x0A7A4B, dark: 0x53D18C)
    
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let rInner: CGFloat = 8
}

private extension Color {
    static func adaptive(light: UInt32, dark: UInt32, alpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
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

struct ProgressView: View {
    @State private var files: [FileItem]
    @State private var isProcessing = false
    @State private var currentProgress = 0
    @State private var isDraggingOver = false
    
    // Multiple operation settings
    @State private var selectedFormat: ImageFormat? = nil
    @State private var selectedResizeMode: BatchResizeMode = .none
    @State private var customPercentText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var selectedDPI: Int? = nil

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
    }
    
    var body: some View {
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
        .padding(30)
        .frame(width: 880, height: 680)
        .background {
            ZStack {
                ProgressDesign.canvas
                LinearGradient(
                    colors: [
                        ProgressDesign.primary.opacity(0.10),
                        ProgressDesign.success.opacity(0.04),
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
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Batch Processor")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ProgressDesign.onSurface)

                Text(isProcessing ? "Processing..." : files.isEmpty ? "Drop images to begin" : "Ready to process")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ProgressDesign.onSurfaceVariant)
            }

            Spacer()

            if !files.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: isProcessing ? "gearshape.2.fill" : "photo.stack")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(files.count)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(ProgressDesign.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ProgressDesign.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    // MARK: - Drop Zone
    
    private var dropZoneView: some View {
        VStack(spacing: 18) {
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
            
            Button("Select Files...") {
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
        .pfCardBackground()
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
                    selectedResizeMode = .none
                    selectedDPI = nil
                    isProcessing = false
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ProgressDesign.primary)
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
                ProgressIndicatorView(current: currentProgress, total: files.count)
                    .padding(.top, 14)
            }
        }
        .padding(18)
        .pfCardBackground()
    }
    
    // MARK: - Controls
    
    private var controlsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(text: "Processing Options")
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ProgressDesign.primary)
                }
                
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                    Text("Resize")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProgressDesign.onSurfaceVariant)
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
                    Label(isProcessing ? "Processing..." : "Start Processing", systemImage: "sparkles")
                }
                .buttonStyle(PrimaryButtonStyle())
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
    
    private func processFiles(urls: [URL], format: ImageFormat?, resize: ResizeOperation?, dpi: Int?) {
        // For now, we'll process them sequentially
        // Format conversion first, then resize, then DPI
        
        if let format = format {
            ImageProcessor.shared.convert(urls, to: format) { done, total in
                currentProgress = done
            } onComplete: { result in
                if let resize = resize {
                    // Continue with resize on the converted files
                    let nextURLs = result.succeeded
                    self.processResize(urls: nextURLs, resize: resize, dpi: dpi)
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
            processResize(urls: urls, resize: resize, dpi: dpi)
        } else if let dpi = dpi {
            processDPI(urls: urls, dpi: dpi)
        }
    }
    
    private func processResize(urls: [URL], resize: ResizeOperation, dpi: Int?) {
        ImageProcessor.shared.resize(urls, operation: resize) { done, total in
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
        selectedResizeMode = .none
        selectedDPI = nil
        currentProgress = 0
    }

    private func resizeEntryRow(label: String, text: Binding<String>, suffix: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ProgressDesign.onSurfaceVariant)
                .frame(width: 96, alignment: .leading)

            TextField("Value", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProgressDesign.onSurface)
                .frame(width: 86)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(ProgressDesign.surface, in: RoundedRectangle(cornerRadius: ProgressDesign.rInner, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ProgressDesign.rInner, style: .continuous)
                        .strokeBorder(resizeInputIsValid ? ProgressDesign.outlineVariant.opacity(0.2) : Color.red.opacity(0.55), lineWidth: 1)
                }
                .onChange(of: text.wrappedValue) { newValue in
                    text.wrappedValue = digitsOnly(newValue)
                }

            Text(suffix)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ProgressDesign.onSurfaceVariant)

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
        .modifier(RowBackgroundModifier())
    }
}

// MARK: - Operation Type

enum Operation {
    case convert(ImageFormat)
    case resize(ResizeOperation)
    case dpi(Int)
    
    var displayName: String {
        switch self {
        case .convert(let format):
            return "Convert to \(format.displayName)"
        case .resize(let resize):
            return resize.displayName
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
            .modifier(CardBackgroundModifier())
    }
}

private struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(ProgressDesign.chrome, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .glassEffect(.regular.tint(ProgressDesign.chrome.opacity(0.34)), in: .rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(ProgressDesign.outlineVariant.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 14)
        } else {
            content
                .background(ProgressDesign.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(ProgressDesign.outlineVariant.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 26, x: 0, y: 12)
        }
    }
}

private extension View {
    func pfCardBackground() -> some View {
        modifier(CardBackgroundModifier())
    }
}

private struct RowBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ProgressDesign.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ProgressDesign.outlineVariant.opacity(0.1), lineWidth: 1)
            }
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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ProgressDesign.primaryGradient,
                        in: RoundedRectangle(cornerRadius: ProgressDesign.rInner, style: .continuous))
            .shadow(color: ProgressDesign.primary.opacity(isEnabled ? 0.22 : 0), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.38)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ProgressDesign.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ProgressDesign.surfaceHigh,
                        in: RoundedRectangle(cornerRadius: ProgressDesign.rInner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ProgressDesign.rInner, style: .continuous)
                    .strokeBorder(ProgressDesign.outlineVariant.opacity(0.16), lineWidth: 1)
            }
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
