import AppKit
import SwiftUI
import ImageIO
import PicFacetCore

// Shared pieces of the Chooser and Batch windows. Each window lays out its own
// pickers (chips vs menus); the draft model, entry field, thumbnails and
// completion alert live here.

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
        alert.informativeText = "\(summary)\nSuccessfully processed \(result.succeeded.count) file(s)."
        if result.hasErrors {
            alert.informativeText += "\n\(result.failed.count) file(s) failed."
        }
        alert.alertStyle = result.hasErrors ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
