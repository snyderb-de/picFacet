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
        }) { [weak self] selection in
            self?.run(selection: selection, urls: urls)
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
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func close() { window?.orderOut(nil) }

    private func run(selection: ChooserSelection, urls: [URL]) {
        guard selection.hasSelection else { return }

        let progress: (Int, Int) -> Void = { d, t in NSLog("[PicFacet] %d/%d", d, t) }
        let complete: (ProcessingResult) -> Void = { r in
            NSLog("[PicFacet] done ok=%d failed=%d", r.succeeded.count, r.failed.count)
            // Show completion alert
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Processing Complete"
                alert.informativeText = "Successfully processed \(r.succeeded.count) file(s)."
                if r.hasErrors {
                    alert.informativeText += "\n\(r.failed.count) file(s) failed."
                }
                alert.alertStyle = r.hasErrors ? .warning : .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }

        func runResize(_ input: [URL], previousFailures: [(url: URL, error: Error)]) {
            guard let resize = selection.resize else {
                runDPI(input, previousFailures: previousFailures)
                return
            }
            ImageProcessor.shared.resize(input, operation: resize, onProgress: progress) { result in
                let failures = previousFailures + result.failed
                if selection.dpi == nil {
                    complete(ProcessingResult(succeeded: result.succeeded, failed: failures))
                } else {
                    runDPI(result.succeeded, previousFailures: failures)
                }
            }
        }

        func runDPI(_ input: [URL], previousFailures: [(url: URL, error: Error)]) {
            guard let dpi = selection.dpi else {
                complete(ProcessingResult(succeeded: input, failed: previousFailures))
                return
            }
            ImageProcessor.shared.changeDPI(input, to: dpi, onProgress: progress) { result in
                complete(ProcessingResult(
                    succeeded: result.succeeded,
                    failed: previousFailures + result.failed
                ))
            }
        }

        if let format = selection.format {
            ImageProcessor.shared.convert(urls, to: format, onProgress: progress) { result in
                if selection.resize == nil && selection.dpi == nil {
                    complete(result)
                } else {
                    runResize(result.succeeded, previousFailures: result.failed)
                }
            }
        } else {
            runResize(urls, previousFailures: [])
        }
    }
}

// MARK: - Operations

struct ChooserSelection: Hashable {
    var format: ImageFormat?
    var resize: ResizeOperation?
    var dpi: Int?

    var hasSelection: Bool {
        format != nil || resize != nil || dpi != nil
    }
}

private enum ResizeMode: Hashable {
    case none
    case percent(Int)
    case customPercent
    case width
    case height
}

// MARK: - View

struct ChooserView: View {
    let urls: [URL]
    let onCancel: () -> Void
    let onPick: (ChooserSelection) -> Void

    @State private var selectedFormat: ImageFormat?
    @State private var selectedResizeMode: ResizeMode = .none
    @State private var customPercentText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var selectedDPI: Int?
    @State private var thumbnails: [URL: NSImage] = [:]

    private let percents = [25, 50, 75]

    init(urls: [URL], onCancel: @escaping () -> Void, onPick: @escaping (ChooserSelection) -> Void) {
        self.urls = urls
        self.onCancel = onCancel
        self.onPick = onPick

        let settings = PicFacetSettings.shared
        _selectedFormat = State(initialValue: settings.defaultFormat)
        _selectedResizeMode = State(initialValue: .percent(Self.validDefaultResize(settings.defaultResizePercent)))
        _selectedDPI = State(initialValue: settings.defaultDPI)
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

    private var resizeOperation: ResizeOperation? {
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
            return resizeOperation != nil
        }
    }

    private var hasSelection: Bool {
        selectedFormat != nil || resizeOperation != nil || selectedDPI != nil
    }

    private var canStart: Bool {
        hasSelection && resizeInputIsValid
    }

    private var operationSummary: String {
        if !resizeInputIsValid {
            return "Enter a positive resize value to continue."
        }

        var parts: [String] = []
        if let format = selectedFormat {
            parts.append("Convert to \(format.displayName)")
        }
        if let resizeOperation {
            parts.append(resizeOperation.displayName)
        }
        if let selectedDPI {
            parts.append("Set \(selectedDPI) DPI")
        }
        return parts.isEmpty ? "Choose at least one operation to continue." : parts.joined(separator: " + ")
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 18) {
                    rootContent
                }
            } else {
                rootContent
            }
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
            DispatchQueue.global(qos: .userInitiated).async {
                if let thumbnail = createThumbnail(for: url) {
                    DispatchQueue.main.async {
                        thumbnails[url] = thumbnail
                    }
                }
            }
        }
    }
    
    private func createThumbnail(for url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let size = NSSize(width: 420, height: 260)
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        let aspectRatio = image.size.width / image.size.height
        var drawRect = NSRect(origin: .zero, size: size)
        
        if aspectRatio > 1 {
            let newHeight = size.width / aspectRatio
            drawRect.origin.y = (size.height - newHeight) / 2
            drawRect.size.height = newHeight
        } else {
            let newWidth = size.height * aspectRatio
            drawRect.origin.x = (size.width - newWidth) / 2
            drawRect.size.width = newWidth
        }
        
        image.draw(in: drawRect)
        thumbnail.unlockFocus()
        
        return thumbnail
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
                    clearChip(title: "Leave as-is", isSelected: selectedFormat == nil) {
                        selectedFormat = nil
                    }
                    ForEach(ImageFormat.allCases, id: \.self) { fmt in
                        PFChip(title: fmt.displayName, isSelected: selectedFormat == fmt, systemImage: formatIcon(for: fmt)) {
                            selectedFormat = fmt
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                optionLabel("Resize", detail: "Scale or constrain dimensions")
                FlowLayout(spacing: 8) {
                    clearChip(title: "Leave as-is", isSelected: selectedResizeMode == .none) {
                        selectedResizeMode = .none
                    }
                    ForEach(percents, id: \.self) { p in
                        PFChip(title: "\(p)%", isSelected: selectedResizeMode == .percent(p), systemImage: "arrow.down.right.and.arrow.up.left") {
                            selectedResizeMode = .percent(p)
                        }
                    }
                    PFChip(title: "Custom %", isSelected: selectedResizeMode == .customPercent, systemImage: "slider.horizontal.3") {
                        selectedResizeMode = .customPercent
                    }
                    PFChip(title: "Set W", isSelected: selectedResizeMode == .width, systemImage: "arrow.left.and.right") {
                        selectedResizeMode = .width
                    }
                    PFChip(title: "Set H", isSelected: selectedResizeMode == .height, systemImage: "arrow.up.and.down") {
                        selectedResizeMode = .height
                    }
                }

                if selectedResizeMode == .customPercent {
                    resizeEntryRow(label: "Custom scale", text: $customPercentText, suffix: "%")
                } else if selectedResizeMode == .width {
                    resizeEntryRow(label: "Target width", text: $widthText, suffix: "px")
                } else if selectedResizeMode == .height {
                    resizeEntryRow(label: "Target height", text: $heightText, suffix: "px")
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                optionLabel("DPI", detail: "Print-resolution metadata")
                FlowLayout(spacing: 8) {
                    clearChip(title: "Leave as-is", isSelected: selectedDPI == nil) {
                        selectedDPI = nil
                    }
                    ForEach(PicFacetSettings.dpiOptions, id: \.self) { d in
                        PFChip(title: "\(d)", isSelected: selectedDPI == d, systemImage: dpiIcon(for: d)) {
                            selectedDPI = d
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

    private func clearChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        PFChip(title: title, isSelected: isSelected, action: action)
    }

    private var summaryBar: some View {
        HStack(spacing: 10) {
            Image(systemName: canStart ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canStart ? PFDesign.success : PFDesign.onSurfaceVariant)
            Text(operationSummary)
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
                onPick(ChooserSelection(
                    format: selectedFormat,
                    resize: resizeOperation,
                    dpi: selectedDPI
                ))
            } label: {
                Label("Start Processing", systemImage: "sparkles")
            }
            .pfPrimaryActionStyle()
            .disabled(!canStart)
        }
        .padding(.top, 4)
    }

    private func resizeEntryRow(label: String, text: Binding<String>, suffix: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)

            TextField("Value", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PFDesign.onSurface)
                .frame(width: 86)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(resizeInputIsValid ? PFDesign.outlineVariant.opacity(0.2) : Color.red.opacity(0.55), lineWidth: 1)
                }
                .onChange(of: text.wrappedValue) { newValue in
                    text.wrappedValue = digitsOnly(newValue)
                }

            Text(suffix)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)

            Spacer()
        }
        .padding(.top, 2)
    }

    private func digitsOnly(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(5))
    }

    private func positiveInt(_ value: String) -> Int? {
        guard let int = Int(value), int > 0 else { return nil }
        return int
    }

    private static func validDefaultResize(_ value: Int) -> Int {
        [25, 50, 75].contains(value) ? value : 50
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
