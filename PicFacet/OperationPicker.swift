import AppKit
import SwiftUI
import ImageIO
import PicFacetCore

// Shared pieces of the Chooser and Batch windows. Each window lays out its own
// pickers (chips vs menus); the draft model, entry field, thumbnails and
// completion alert live here.

/// Every processing option as a labelled menu, with typed values (resize,
/// custom size limit, watermark, rename) under their menus.
/// Used by both the Chooser and the Batch window.
struct OperationMenus: View {
    @Binding var draft: OperationDraft
    /// Files in the queue, for the rename preview.
    var sampleURLs: [URL] = []
    var labelWidth: CGFloat = 60
    var menuWidth: CGFloat? = nil
    /// Short hints under each label.
    var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("Format", detail: "Output file type") {
                Picker("", selection: $draft.format) {
                    Text("No Change").tag(nil as ImageFormat?)
                    Divider()
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(Optional(format))
                    }
                }
            }

            row("Quality", detail: "JPEG, WebP, HEIC, AVIF") {
                Picker("", selection: $draft.quality) {
                    Text("Default").tag(nil as Int?)
                    Divider()
                    ForEach(QualityPreset.all, id: \.value) { preset in
                        Text(preset.title).tag(Optional(preset.value))
                    }
                    if let quality = draft.quality, !QualityPreset.all.contains(where: { $0.value == quality }) {
                        Text("Quality \(quality)").tag(Optional(quality))
                    }
                }
                .disabled(draft.format.map { !$0.isLossy } ?? false)
                .help(draft.format.map { $0.isLossy ? "" : "\($0.displayName) is lossless; quality doesn't apply." } ?? "")
            }

            VStack(alignment: .leading, spacing: 8) {
                row("Resize", detail: "Scale or set a size") {
                    Picker("", selection: $draft.resizeMode) {
                        ForEach(ResizeMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                            if mode == .none { Divider() }
                        }
                    }
                }
                ResizeEntryRow(draft: $draft, showsLabel: false)
                    .padding(.leading, labelWidth + 8)
            }

            row("Crop", detail: "Centre to a ratio") {
                Picker("", selection: $draft.crop) {
                    Text("Original").tag(nil as CropRatio?)
                    Divider()
                    ForEach(CropRatio.presets, id: \.self) { ratio in
                        Text(ratio.label).tag(Optional(ratio))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                row("File size", detail: "Shrink to fit a limit") {
                    Picker("", selection: $draft.targetSize) {
                        ForEach(TargetSizeChoice.allCases, id: \.self) { choice in
                            Text(choice.title).tag(choice)
                            if choice == .none { Divider() }
                        }
                    }
                }
                if draft.targetSize == .custom {
                    NumberEntry(text: $draft.targetKBText, placeholder: "Max size", suffix: "KB", isValid: draft.targetIsValid)
                        .padding(.leading, labelWidth + 8)
                }
            }

            row("DPI", detail: "Print resolution") {
                Picker("", selection: $draft.dpi) {
                    Text("No Change").tag(nil as Int?)
                    Divider()
                    ForEach(PicFacetSettings.dpiOptions, id: \.self) { dpi in
                        Text("\(dpi) DPI").tag(Optional(dpi))
                    }
                }
            }

            row("Metadata", detail: "Privacy before sharing") {
                Picker("", selection: $draft.metadata) {
                    Text("Keep All").tag(nil as MetadataMode?)
                    Divider()
                    ForEach(MetadataMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(Optional(mode))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                row("Watermark", detail: "Text or logo") {
                    Picker("", selection: $draft.watermarkKind) {
                        ForEach(WatermarkKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                            if kind == .none { Divider() }
                        }
                    }
                }
                if draft.watermarkKind != .none {
                    WatermarkOptions(draft: $draft)
                        .padding(.leading, labelWidth + 8)
                }
            }

            row("Rename", detail: "Output name pattern") {
                HStack(spacing: 6) {
                    Button { isEditingRename = true } label: {
                        HStack(spacing: 6) {
                            Text(draft.renameTemplate.isEmpty ? "Keep Names" : draft.renameTemplate)
                                .font(.system(size: 12, weight: .medium,
                                              design: draft.renameTemplate.isEmpty ? .default : .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .help("Edit the rename pattern")
                    if !draft.renameTemplate.isEmpty {
                        Button { draft.renameTemplate = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(PFDesign.onSurfaceVariant)
                            .help("Keep original names")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingRename) {
            RenameEditor(template: $draft.renameTemplate, samples: sampleURLs, selection: renameContext)
        }
    }

    @State private var isEditingRename = false

    /// The draft's other options, for the rename preview's format and size.
    private var renameContext: BatchSelection {
        var context = OperationDraft(format: draft.format, resizeMode: draft.resizeMode, dpi: nil)
        context.entryText = draft.entryText
        context.crop = draft.crop
        return context.selection ?? BatchSelection(format: draft.format, crop: draft.crop)
    }

    private func row<Menu: View>(_ title: String, detail: String? = nil, @ViewBuilder menu: () -> Menu) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: showsDetails ? 13 : 12, weight: showsDetails ? .semibold : .medium))
                    .foregroundStyle(showsDetails ? PFDesign.onSurface : PFDesign.onSurfaceVariant)
                if showsDetails, let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                }
            }
            .frame(width: labelWidth, alignment: .leading)

            menu()
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: menuWidth ?? .infinity, alignment: .leading)

            if menuWidth != nil { Spacer(minLength: 0) }
        }
    }
}

/// Text or logo, position and size for the draft's watermark.
private struct WatermarkOptions: View {
    @Binding var draft: OperationDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if draft.watermarkKind == .text {
                TextField("© Your Name", text: $draft.watermark.text)
                    .pfEntryField(isValid: draft.watermarkIsValid)
            } else {
                HStack(spacing: 8) {
                    Button(draft.watermark.logoPath == nil ? "Choose Logo…" : "Change…", action: chooseLogo)
                        .controlSize(.small)
                    Text(draft.watermark.logoPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "PNG with transparency works best")
                        .font(.system(size: 11))
                        .foregroundStyle(draft.watermarkIsValid ? PFDesign.onSurfaceVariant : .red)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            HStack(spacing: 8) {
                Picker("Position", selection: $draft.watermark.position) {
                    ForEach(Watermark.Position.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Size", selection: $draft.watermark.size) {
                    ForEach(Watermark.Size.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }

    private func chooseLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a logo to stamp on each image"
        if panel.runModal() == .OK, let url = panel.url {
            draft.watermark.logoPath = url.path
        }
    }
}

extension View {
    /// The inset text-field look used for typed values.
    func pfEntryField(isValid: Bool, width: CGFloat? = nil) -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(PFDesign.onSurface)
            .frame(width: width)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                    .strokeBorder(isValid ? PFDesign.outlineVariant.opacity(0.2) : Color.red.opacity(0.55), lineWidth: 1)
            }
    }
}

/// Digits-only field bound to a draft value that filters its own input.
/// TextField keeps its own editing text unless the bound value changes, so
/// rejected characters are pushed back explicitly.
struct NumberEntry: View {
    @Binding var text: String
    let placeholder: String
    let suffix: String
    var isValid = true

    @State private var editing: String

    init(text: Binding<String>, placeholder: String, suffix: String, isValid: Bool = true) {
        _text = text
        self.placeholder = placeholder
        self.suffix = suffix
        self.isValid = isValid
        // Seeded here, not on appear: a focused field's editor would push its
        // empty text back over a value set after the first render.
        _editing = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $editing)
                .pfEntryField(isValid: isValid, width: 86)
                .onChange(of: editing) { _, newValue in
                    text = newValue
                    if editing != text { editing = text }
                }
                .onChange(of: text) { _, newValue in
                    if editing != newValue { editing = newValue }
                }
            Text(suffix)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)
            Spacer()
        }
    }
}

/// Text field for the typed resize value of the draft's current mode.
/// Shows nothing when the mode needs no value.
struct ResizeEntryRow: View {
    @Binding var draft: OperationDraft
    /// Off where the picker right above already names the mode.
    var showsLabel = true

    /// Mirrors the draft's value. The draft filters input, and TextField keeps its
    /// own editing text unless the bound value changes, so rejected characters are
    /// pushed back here explicitly.
    @State private var text: String

    init(draft: Binding<OperationDraft>, showsLabel: Bool = true) {
        _draft = draft
        self.showsLabel = showsLabel
        // Seeded here, not on appear: a focused field's editor would push its
        // empty text back over a value set after the first render (e.g. a recipe).
        _text = State(initialValue: draft.wrappedValue.entryText)
    }

    var body: some View {
        if let entry = draft.resizeMode.entry {
            HStack(spacing: 8) {
                if showsLabel {
                    Text(entry.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                }

                TextField(entry.label, text: $text)
                    .pfEntryField(isValid: draft.entryIsValid, width: 86)
                    .onChange(of: text) { _, newValue in
                        draft.entryText = newValue
                        if text != draft.entryText { text = draft.entryText }
                    }
                    // Mode switches and loaded recipes change the value from outside.
                    .onChange(of: draft.entryText) { _, newValue in
                        if text != newValue { text = newValue }
                    }

                Text(entry.suffix)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PFDesign.onSurfaceVariant)

                Spacer()
            }
        }
    }
}

enum Thumbnail {
    /// Decodes a downsampled thumbnail off the main actor.
    static func load(_ url: URL, maxPixelSize: Int) async -> NSImage? {
        let cgImage = await Task.detached(priority: .userInitiated) {
            decode(url, maxPixelSize: maxPixelSize)
        }.value
        return cgImage.map { NSImage(cgImage: $0, size: .zero) }
    }

    nonisolated private static func decode(_ url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

enum CompletionAlert {
    static func show(_ result: ProcessingResult, summary: String) {
        let alert = NSAlert()
        alert.messageText = "Processing Complete"

        var lines = [summary, "Saved \(result.succeeded.count) file(s)."]
        if let savings = result.savingsText { lines.append(savings) }
        let notes = result.reports.filter { $0.note != nil }
        if !notes.isEmpty {
            lines.append("\(notes.count) file(s) couldn't reach the size limit; the smallest version was saved: \(names(notes.map(\.source))).")
        }
        let kept = result.keptOriginal
        if !kept.isEmpty {
            lines.append("Kept \(kept.count) original(s) unchanged because the result wasn't smaller: \(names(kept)).")
        }
        let failed = result.failed
        if !failed.isEmpty {
            lines.append("\(failed.count) file(s) failed: \(names(failed.map(\.url))).")
        }
        alert.informativeText = lines.joined(separator: "\n")
        alert.alertStyle = result.hasErrors ? .warning : .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    /// Up to three file names, then a count of the rest.
    private static func names(_ urls: [URL]) -> String {
        let shown = urls.prefix(3).map(\.lastPathComponent).joined(separator: ", ")
        return urls.count > 3 ? "\(shown) and \(urls.count - 3) more" : shown
    }
}

// MARK: - Activity log

/// One batch run in the activity log.
struct ActivityRun: Identifiable {
    let id = UUID()
    let summary: String
    let started = Date()
    /// Newest first.
    var reports: [FileReport] = []
    /// Total size change, set when the run finishes.
    var savings: String?
}

/// Per-file results of past runs, newest run first.
struct ActivityLogView: View {
    let runs: [ActivityRun]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PFSectionLabel(text: "Activity")
                Spacer()
                if !runs.isEmpty {
                    Button("Clear", action: onClear)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PFDesign.primary)
                }
            }

            if runs.isEmpty {
                Text("Results for each file appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(runs) { run in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(run.started.formatted(date: .omitted, time: .shortened)) · \(run.summary)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PFDesign.onSurfaceVariant)
                                    .lineLimit(2)
                                if let savings = run.savings {
                                    Label(savings, systemImage: "arrow.down.circle")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(PFDesign.success)
                                }
                                ForEach(Array(run.reports.enumerated()), id: \.offset) { ActivityRow(report: $0.element) }
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }
}

private struct ActivityRow: View {
    let report: FileReport

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(report.source.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PFDesign.onSurface)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .help(detail)
    }

    private var icon: String {
        switch report.outcome {
        case .written: report.note == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        case .keptOriginal: "arrow.uturn.backward.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch report.outcome {
        case .written: report.note == nil ? PFDesign.success : PFDesign.amber
        case .keptOriginal: PFDesign.amber
        case .failed: .red
        }
    }

    private var detail: String {
        switch report.outcome {
        case .written(let url):
            var name = url.path == report.source.path ? "Overwritten" : "Saved as \(url.lastPathComponent)"
            if !report.extraOutputs.isEmpty { name += " + \(report.extraOutputs.count) more page(s)" }
            return [name, sizeChange, report.note].compactMap { $0 }.joined(separator: " · ")
        case .keptOriginal:
            guard let sizeChange else { return "Kept original" }
            return "Kept original · \(sizeChange), not smaller"
        case .failed(let error):
            return error.localizedDescription
        }
    }

    private var sizeChange: String? {
        guard let before = report.originalBytes, let after = report.resultBytes else { return nil }
        return "\(Self.bytes(before)) → \(Self.bytes(after))"
    }

    private static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

// MARK: - Recipes

/// Load a saved recipe into the draft, or save the draft as one.
struct RecipeMenu: View {
    @Binding var draft: OperationDraft
    @State private var recipes = RecipeStore.all

    var body: some View {
        Menu {
            if recipes.isEmpty {
                Text("No saved recipes")
            }
            ForEach(recipes) { recipe in
                Button(recipe.name) { draft = OperationDraft(selection: recipe.selection) }
            }
            Divider()
            Button("Save Current as Recipe…") {
                if let selection = draft.selection { RecipeStore.promptToSave(selection) }
            }
            .disabled(draft.selection == nil)
            Button("Manage Recipes…") { SettingsWindowController.shared.show() }
        } label: {
            Label("Recipes", systemImage: "wand.and.stars")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(PFDesign.primary)
        .onReceive(NotificationCenter.default.publisher(for: .picFacetRecipesChanged)) { _ in
            recipes = RecipeStore.all
        }
    }
}
