import SwiftUI
import PicFacetCore

/// "Show Me How" for the Rename window: a small, self-contained animation
/// that builds {name}-{date}-{n} in a mock name field, with play controls.
/// It never touches the user's pattern. Closing the popover stops it.
struct RenameDemo: View {
    var onClose: () -> Void = {}

    private enum Action {
        case drag(String)
        case type(String)
    }

    private static let steps: [(action: Action, caption: String)] = [
        (.drag("{name}"), "Drag {name} into the name. It becomes each file’s original name."),
        (.type("-"), "Type a dash to separate the parts."),
        (.drag("{date}"), "Drag {date}. It becomes today’s date."),
        (.type("-"), "Type another dash."),
        (.drag("{n}"), "Drag {n}. Each file gets its own number, so names never clash.")
    ]

    private static let chips = ["{name}", "{date}", "{n}"]
    nonisolated private static let space = "renameDemo"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pattern = ""
    /// Index of the next step to run; `steps.count` when finished.
    @State private var stepIndex = 0
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>?

    @State private var fieldFrame: CGRect = .zero
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var ghostToken = ""
    @State private var ghostAt: CGPoint?
    @State private var ghostOpacity = 0.0

    private var isFinished: Bool { stepIndex >= Self.steps.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("How renaming works")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                Spacer()
                Button(action: close) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .help("Close")
                    .keyboardShortcut(.cancelAction)
            }

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(PFDesign.onSurfaceVariant)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: stepIndex)

            // Mock name field.
            Text(pattern.isEmpty ? "Batch Rename here" : pattern)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(pattern.isEmpty ? PFDesign.onSurfaceVariant.opacity(0.6) : PFDesign.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                        .strokeBorder(PFDesign.primary.opacity(ghostAt == nil ? 0.15 : 0.5), lineWidth: 1)
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { fieldFrame = $0 }

            HStack(spacing: 8) {
                ForEach(Self.chips, id: \.self) { token in
                    chip(token)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                            chipFrames[token] = $0
                        }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(0..<2, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text(Self.samples[i])
                            .foregroundStyle(PFDesign.onSurfaceVariant)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PFDesign.onSurfaceVariant)
                        Text(preview(i))
                            .fontWeight(.semibold)
                            .foregroundStyle(PFDesign.onSurface)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))

            controls
        }
        .padding(16)
        .frame(width: 380)
        .coordinateSpace(name: Self.space)
        .overlay(alignment: .topLeading) { ghost }
        .background(PFDesign.canvas)
        .tint(PFDesign.primary)
        .onAppear {
            // A beat for layout, then play.
            playTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                play()
            }
        }
        .onDisappear(perform: pause)
    }

    // MARK: Pieces

    private var caption: String {
        isFinished
            ? "Done. Every saved file now gets its own name, like the preview below."
            : Self.steps[stepIndex].caption
    }

    private func chip(_ token: String) -> some View {
        Text(token)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(PFDesign.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(PFDesign.surfaceLow, in: Capsule())
            .opacity(ghostAt != nil && ghostToken == token ? 0.45 : 1)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: restart) {
                Image(systemName: "backward.end.fill")
            }
            .help("Restart")

            Button(action: { isPlaying ? pause() : (isFinished ? restart() : play()) }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 16)
            }
            .help(isPlaying ? "Pause" : "Play")
            .keyboardShortcut(.space, modifiers: [])

            HStack(spacing: 5) {
                ForEach(0..<Self.steps.count, id: \.self) { i in
                    Circle()
                        .fill(i < stepIndex ? PFDesign.primary : PFDesign.onSurfaceVariant.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(min(stepIndex + 1, Self.steps.count)) of \(Self.steps.count)")

            Spacer()
        }
        .buttonStyle(.borderless)
        .font(.system(size: 13))
    }

    @ViewBuilder
    private var ghost: some View {
        if let ghostAt {
            HStack(spacing: 2) {
                chip(ghostToken)
                    .opacity(1)
                    .background(PFDesign.surfaceLowest, in: Capsule())
                    .overlay { Capsule().strokeBorder(PFDesign.primary.opacity(0.6), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PFDesign.onSurface)
                    .offset(x: -8, y: 11)
            }
            .fixedSize()
            .position(ghostAt)
            .opacity(ghostOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: Preview

    private static let samples = ["IMG_4021.heic", "IMG_4022.heic"]

    private func preview(_ index: Int) -> String {
        let name = URL(fileURLWithPath: Self.samples[index]).deletingPathExtension().lastPathComponent
        let rename = RenamePattern(pattern)
        guard !rename.isEmpty else { return "\(name).jpg" }
        let base = rename.apply(.init(name: name, index: index, count: 2,
                                      width: 4032, height: 3024, fileExtension: "jpg"))
        return "\(base).jpg"
    }

    // MARK: Playback

    private func play() {
        guard !isPlaying, !isFinished else { return }
        isPlaying = true
        playTask?.cancel()
        playTask = Task {
            while !isFinished, !Task.isCancelled {
                await run(Self.steps[stepIndex].action)
                guard !Task.isCancelled else { return }
                stepIndex += 1
                try? await Task.sleep(for: .milliseconds(650))
            }
            isPlaying = false
        }
    }

    /// Stops after the current moment; the half-done step replays on Play.
    private func pause() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        ghostAt = nil
        ghostOpacity = 0
    }

    private func restart() {
        pause()
        pattern = ""
        stepIndex = 0
        play()
    }

    private func close() {
        pause()
        onClose()
    }

    private func run(_ action: Action) async {
        switch action {
        case .type(let text):
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            pattern += text
        case .drag(let token):
            if !reduceMotion { await glide(token) }
            guard !Task.isCancelled else { return }
            pattern += token
        }
    }

    /// The token's chip lifts, travels to the end of the field's text, drops.
    private func glide(_ token: String) async {
        guard let chip = chipFrames[token], fieldFrame != .zero else { return }
        ghostToken = token
        ghostAt = CGPoint(x: chip.midX + 6, y: chip.midY)
        withAnimation(.easeOut(duration: 0.15)) { ghostOpacity = 1 }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        let charWidth: CGFloat = 7.9  // 13 pt monospaced
        let endX = min(fieldFrame.minX + 10 + CGFloat(pattern.count) * charWidth + 32, fieldFrame.maxX - 30)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            ghostAt = CGPoint(x: endX, y: fieldFrame.midY)
        }
        try? await Task.sleep(for: .milliseconds(800))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.15)) { ghostOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(160))
        ghostAt = nil
    }
}
