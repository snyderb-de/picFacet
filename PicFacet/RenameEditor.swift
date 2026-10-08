import SwiftUI
import PicFacetCore

/// Window for building a rename pattern: tokens to click, ready-made
/// examples, and a live preview using the files in the queue.
struct RenameEditor: View {
    @Binding var template: String
    /// Files in the queue, for the preview. May be empty (Batch window before a drop).
    let samples: [URL]
    /// The rest of the run's options, so the preview shows the saved
    /// format and pixel size.
    let selection: BatchSelection

    @Environment(\.dismiss) private var dismiss
    @State private var pattern: String
    @State private var infos: [URL: ImageInfo] = [:]

    // Drag hint: a ghost chip glides from the first token into the name field.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Times the hint has played; it stops after `dragHintLimit`.
    @AppStorage("renameDragHintCount") private var dragHintCount = 0
    private static let dragHintLimit = 3
    @State private var fieldFrame: CGRect = .zero
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var ghostToken = "{name}"
    @State private var isShowingDemo = false
    @State private var ghostAt: CGPoint?
    @State private var ghostOpacity = 0.0
    @State private var hoveredToken: String?

    init(template: Binding<String>, samples: [URL], selection: BatchSelection) {
        _template = template
        self.samples = samples
        self.selection = selection
        _pattern = State(initialValue: template.wrappedValue)
    }

    private static let tokens: [(token: String, meaning: String)] = [
        ("{name}", "Original file name"),
        ("{n}", "Number in the batch: 01, 02, 03…"),
        ("{date}", "Today’s date, like 2026-10-08"),
        ("{width}", "Width of the saved image in pixels"),
        ("{height}", "Height of the saved image in pixels"),
        ("{format}", "File type, like jpg or png")
    ]

    private static let examples: [(pattern: String, use: String)] = [
        ("{name}-web", "Keep the name, mark the copy"),
        ("vacation-{n}", "Number a set of photos"),
        ("{date}-{n}", "Date and number"),
        ("{name}-{width}x{height}", "Name with the new size"),
        ("{date}_{name}", "Date first, sorts by day")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rename Files")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                Text("Build a name for each saved file. Drag a token into the name, or click it to add it at the end. Type anything else as plain text. The file extension is added for you.")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                TextField("Batch Rename here", text: $pattern)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .pfEntryField(isValid: true)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { fieldFrame = $0 }
                if !pattern.isEmpty {
                    Button { pattern = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                        .help("Clear")
                }
            }

            section("Tokens", accessory: {
                Button { isShowingDemo = true } label: {
                    Label("Show Me How", systemImage: "play.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .tint(PFDesign.primary)
                .help("Watch a name being built from tokens")
                .popover(isPresented: $isShowingDemo, arrowEdge: .bottom) {
                    RenameDemo { isShowingDemo = false }
                }
            }) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Self.tokens, id: \.token) { item in
                        Button { add(item.token) } label: {
                            HStack(spacing: 8) {
                                // Grip: reads as "this can be picked up".
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PFDesign.onSurfaceVariant.opacity(hoveredToken == item.token ? 0.9 : 0.45))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.token)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(PFDesign.primary)
                                    Text(item.meaning)
                                        .font(.system(size: 11))
                                        .foregroundStyle(PFDesign.onSurfaceVariant)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                                    .strokeBorder(PFDesign.primary.opacity(hoveredToken == item.token ? 0.5 : 0), lineWidth: 1)
                            }
                            .scaleEffect(hoveredToken == item.token ? 1.02 : 1)
                            .shadow(color: .black.opacity(hoveredToken == item.token ? 0.12 : 0), radius: 4, y: 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.grabIdle)
                        .onHover { inside in
                            withAnimation(.easeOut(duration: 0.12)) {
                                hoveredToken = inside ? item.token : (hoveredToken == item.token ? nil : hoveredToken)
                            }
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frame in
                            chipFrames[item.token] = frame
                        }
                        // Drop on the name field to insert it where you release.
                        .draggable(item.token) {
                            Text(item.token)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PFDesign.primary.opacity(0.2), in: Capsule())
                        }
                        .help("Click to add \(item.token) at the end, or drag it into the name")
                    }
                }
            }

            section("Examples") {
                VStack(spacing: 6) {
                    ForEach(Self.examples, id: \.pattern) { example in
                        Button { pattern = example.pattern } label: {
                            HStack(spacing: 10) {
                                Text(example.pattern)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(PFDesign.onSurface)
                                    .frame(width: 175, alignment: .leading)
                                Text(example.use)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PFDesign.onSurfaceVariant)
                                    .lineLimit(1)
                                Spacer()
                                Text(result(example.pattern, index: 0) ?? "")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(PFDesign.onSurfaceVariant)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(pattern == example.pattern ? PFDesign.primary.opacity(0.14) : PFDesign.surfaceLow,
                                        in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            section("Preview") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(previewNames.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 8) {
                            Text(row.from)
                                .foregroundStyle(PFDesign.onSurfaceVariant)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PFDesign.onSurfaceVariant)
                            Text(row.to)
                                .foregroundStyle(PFDesign.onSurface)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.system(size: 12, design: .monospaced))
                    }
                    if samples.isEmpty {
                        Text("Example names shown. Add images to preview your own files.")
                            .font(.system(size: 11))
                            .foregroundStyle(PFDesign.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
            }

            HStack {
                Button("Keep Original Names") {
                    template = ""
                    dismiss()
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Use Pattern") {
                    template = pattern.trimmingCharacters(in: .whitespaces)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pattern.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
        .coordinateSpace(name: Self.space)
        .overlay(alignment: .topLeading) { dragGhost }
        .background(PFDesign.canvas)
        .task { await playDragHintIfNeeded() }
        .tint(PFDesign.primary)
        .task(id: samples) {
            for url in samples.prefix(3) { infos[url] = await ImageInfo.load(url) }
        }
    }

    // MARK: Drag hint

    private static let space = "renameEditor"

    /// A copy of the first token chip with a hand, shown only while the hint plays.
    @ViewBuilder
    private var dragGhost: some View {
        if let ghostAt {
            HStack(spacing: 4) {
                Text(ghostToken)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PFDesign.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(PFDesign.surfaceLowest, in: Capsule())
                    .overlay { Capsule().strokeBorder(PFDesign.primary.opacity(0.6), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(PFDesign.onSurface)
                    .offset(x: -8, y: 12)
            }
            .fixedSize()
            .position(ghostAt)
            .opacity(ghostOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Shows a token gliding into the name field: chip lifts, travels,
    /// drops, fades. Plays for the first few opens, never with Reduce Motion.
    private func playDragHintIfNeeded() async {
        guard !reduceMotion, dragHintCount < Self.dragHintLimit else { return }
        try? await Task.sleep(for: .milliseconds(700))  // let the sheet settle and frames arrive
        guard fieldFrame != .zero, !Task.isCancelled else { return }
        dragHintCount += 1
        await glide("{name}", to: CGPoint(x: fieldFrame.minX + 70, y: fieldFrame.midY))
    }

    /// Moves a ghost of `token`'s chip to `end`, then fades it out.
    private func glide(_ token: String, to end: CGPoint) async {
        guard let chip = chipFrames[token] else { return }
        ghostToken = token
        ghostAt = CGPoint(x: chip.minX + 60, y: chip.midY)
        withAnimation(.easeOut(duration: 0.18)) { ghostOpacity = 1 }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) { ghostAt = end }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeIn(duration: 0.18)) { ghostOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(200))
        ghostAt = nil
    }

    /// Appends a token, with a "-" between it and a token right before it,
    /// so {n}{name} doesn't run together.
    private func add(_ token: String) {
        if pattern.hasSuffix("}") { pattern += "-" }
        pattern += token
    }

    // MARK: Preview

    /// Stand-in files when the queue is empty.
    private static let placeholders: [(name: String, ext: String, width: Int, height: Int)] = [
        ("IMG_4021", "heic", 4032, 3024), ("IMG_4022", "heic", 4032, 3024), ("beach", "jpg", 3000, 2000)
    ]

    private struct Source {
        let name: String
        let ext: String
        let width: Int
        let height: Int
    }

    private var sources: [Source] {
        if samples.isEmpty {
            return Self.placeholders.map { Source(name: $0.name, ext: $0.ext, width: $0.width, height: $0.height) }
        }
        return samples.prefix(3).map { url in
            let info = infos[url]
            return Source(name: url.deletingPathExtension().lastPathComponent, ext: url.pathExtension.lowercased(),
                          width: info?.pixelWidth ?? 0, height: info?.pixelHeight ?? 0)
        }
    }

    private var count: Int { samples.isEmpty ? Self.placeholders.count : samples.count }

    /// "IMG_4021.heic" → "IMG_4021-web.jpg", for up to three files.
    private var previewNames: [(from: String, to: String)] {
        sources.indices.map { i in
            let source = sources[i]
            return ("\(source.name).\(source.ext)", result(pattern, index: i) ?? "\(source.name).\(outputExtension(source))")
        }
    }

    private func outputExtension(_ source: Source) -> String {
        selection.format?.fileExtension ?? source.ext
    }

    /// The saved file name for source `index` under `pattern`, or nil for an empty pattern.
    private func result(_ pattern: String, index: Int) -> String? {
        let rename = RenamePattern(pattern)
        guard !rename.isEmpty, sources.indices.contains(index) else { return nil }
        let source = sources[index]
        let size = selection.outputPixelSize(width: source.width, height: source.height,
                                             proportional: PicFacetSettings.shared.isProportional)
        let ext = outputExtension(source)
        let base = rename.apply(.init(name: source.name, index: index, count: count,
                                      width: size.width, height: size.height, fileExtension: ext))
        return "\(base).\(ext)"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        section(title, accessory: { EmptyView() }, content: content)
    }

    private func section<Accessory: View, Content: View>(
        _ title: String, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PFSectionLabel(text: title)
                Spacer()
                accessory()
            }
            content()
        }
    }
}
