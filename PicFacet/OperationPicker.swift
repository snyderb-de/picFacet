import AppKit
import SwiftUI
import ImageIO
import PicFacetCore

// Shared pieces of the Chooser and Batch windows. Each window lays out its own
// pickers (chips vs menus); the draft model, entry field, thumbnails and
// completion alert live here.

/// Format, resize and DPI menus with the typed resize value under them.
/// Used by both the Chooser and the Batch window.
struct OperationMenus: View {
    @Binding var draft: OperationDraft
    var labelWidth: CGFloat = 60
    var menuWidth: CGFloat? = nil
    /// Short hints under the Format and Resize labels.
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

            row("DPI") {
                Picker("", selection: $draft.dpi) {
                    Text("No Change").tag(nil as Int?)
                    Divider()
                    ForEach(PicFacetSettings.dpiOptions, id: \.self) { dpi in
                        Text("\(dpi) DPI").tag(Optional(dpi))
                    }
                }
            }
        }
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

/// Text field for the typed resize value of the draft's current mode.
/// Shows nothing when the mode needs no value.
struct ResizeEntryRow: View {
    @Binding var draft: OperationDraft
    /// Off where the picker right above already names the mode.
    var showsLabel = true

    /// Mirrors the draft's value. The draft filters input, and TextField keeps its
    /// own editing text unless the bound value changes, so rejected characters are
    /// pushed back here explicitly.
    @State private var text = ""

    var body: some View {
        if let entry = draft.resizeMode.entry {
            HStack(spacing: 8) {
                if showsLabel {
                    Text(entry.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                }

                TextField(entry.label, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                    .frame(width: 86)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                            .strokeBorder(draft.entryIsValid ? PFDesign.outlineVariant.opacity(0.2) : Color.red.opacity(0.55), lineWidth: 1)
                    }
                    .onChange(of: text) { _, newValue in
                        draft.entryText = newValue
                        if text != draft.entryText { text = draft.entryText }
                    }
                    .onChange(of: draft.resizeMode, initial: true) {
                        text = draft.entryText
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
        case .written: "checkmark.circle.fill"
        case .keptOriginal: "arrow.uturn.backward.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch report.outcome {
        case .written: PFDesign.success
        case .keptOriginal: PFDesign.amber
        case .failed: .red
        }
    }

    private var detail: String {
        switch report.outcome {
        case .written(let url):
            let name = url.path == report.source.path ? "Overwritten" : "Saved as \(url.lastPathComponent)"
            return [name, sizeChange].compactMap { $0 }.joined(separator: " · ")
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
