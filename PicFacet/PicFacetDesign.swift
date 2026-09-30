import AppKit
import SwiftUI

/// Shared PicFacet design tokens.
/// The visual goal is a premium Mac utility: crisp hierarchy, native material,
/// restrained color, and controls that look trustworthy around user files.
enum PFDesign {
    // MARK: Surfaces
    static let canvas           = Color.adaptive(light: 0xF6F7F9, dark: 0x111418)
    static let surfaceLow       = Color.adaptive(light: 0xECEFF3, dark: 0x1B2026)
    static let surfaceLowest    = Color.adaptive(light: 0xFFFFFF, dark: 0x242A32)
    static let surfaceHigh      = Color.adaptive(light: 0xDDE3EA, dark: 0x303842)
    static let chrome           = Color.adaptive(light: 0xFBFCFE, dark: 0x181D23, alpha: 0.56)

    // MARK: Ink
    static let onSurface        = Color.adaptive(light: 0x161A1F, dark: 0xF5F7FA)
    static let onSurfaceVariant = Color.adaptive(light: 0x5D6673, dark: 0xB7C0CC)
    static let outlineVariant   = Color.adaptive(light: 0xBCC6D2, dark: 0x485360)

    // MARK: Accent (user-chosen, see Theme)
    static var primary: Color { Theme.shared.accent }
    static var primaryBright: Color { primary.mix(with: .white, by: 0.3) }
    static let success          = Color.adaptive(light: 0x0A7A4B, dark: 0x53D18C)
    static let amber            = Color.adaptive(light: 0x9B5B00, dark: 0xF0B44D)
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [primary, primaryBright], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Radii
    static let rCard: CGFloat  = 8
    static let rInner: CGFloat = 8
    /// Window-level panels. Large and continuous, like macOS 26 sidebars, so
    /// glass edges read as Liquid Glass rather than a frosted box.
    static let rPanel: CGFloat = 20

    /// Window backdrop: the canvas with the user's gradient washed over it.
    /// Glass needs something under it to refract.
    static var backdrop: some View {
        ZStack {
            canvas
            BackdropWash(colors: Theme.shared.backdropColors)
        }
        .ignoresSafeArea()
    }
}

/// The gradient part of the backdrop. Kept faint so text stays readable in
/// light and dark mode whatever colours are picked.
struct BackdropWash: View {
    let colors: [Color]

    var body: some View {
        if colors.count == 2 {
            LinearGradient(
                colors: [colors[0].opacity(0.24), colors[1].opacity(0.12), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Color hex helper

extension Color {
    static func adaptive(light: UInt32, dark: UInt32, alpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
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

// MARK: - Card container

struct PFCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(22)
            .modifier(PFPanelBackground(interactive: false))
    }
}

/// Liquid Glass panel for the control layer (options, activity). The system
/// draws the edge highlight and shadow, so no stroke or shadow is added here.
struct PFPanelBackground: ViewModifier {
    var interactive: Bool = false

    func body(content: Content) -> some View {
        content
            .glassEffect(interactive ? .regular.interactive() : .regular,
                         in: .rect(cornerRadius: PFDesign.rPanel))
    }
}

/// Solid panel for the content layer (files, previews). Apple's guidance is to
/// keep glass off content, so this is an opaque surface with a hairline.
struct PFContentPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PFDesign.surfaceLowest.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: PFDesign.rPanel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PFDesign.rPanel, style: .continuous)
                    .strokeBorder(PFDesign.outlineVariant.opacity(0.28), lineWidth: 0.5)
            }
    }
}

extension View {
    func pfPanel(interactive: Bool = false) -> some View {
        modifier(PFPanelBackground(interactive: interactive))
    }

    func pfContentPanel() -> some View {
        modifier(PFContentPanelBackground())
    }
}

/// Small uppercase label used to head sections inside a card.
struct PFSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(PFDesign.onSurfaceVariant)
    }
}

// MARK: - Actions

extension View {
    func pfPrimaryActionStyle() -> some View {
        self
            .buttonSizing(.flexible)
            .frame(maxWidth: .infinity)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(PFDesign.primary)
    }

    func pfSecondaryActionStyle() -> some View {
        self
            .buttonStyle(.glass)
            .controlSize(.regular)
    }
}

struct PFStatPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PFDesign.primary)
                .frame(width: 24, height: 24)
                .background(PFDesign.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                .strokeBorder(PFDesign.outlineVariant.opacity(0.16), lineWidth: 1)
        }
    }
}

// MARK: - Empty state view

struct PFEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(PFDesign.onSurfaceVariant.opacity(0.4))
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionLabel = actionLabel {
                Button(actionLabel, action: action)
                    .pfSecondaryActionStyle()
                    .padding(.top, 4)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Run bar

/// Shows what a run will do, then fills up while it runs. The label is drawn
/// twice (plain on the track, white on the fill) so it stays readable as the
/// fill passes under it.
struct PFRunBar: View {
    let summary: String
    var isReady: Bool = true
    /// nil while idle.
    var progress: (completed: Int, total: Int)? = nil

    @Environment(\.self) private var environment

    /// Label colour on the fill: dark on light accents (most dark-mode
    /// presets), white on deep ones.
    private var onFill: Color {
        let c = PFDesign.primary.resolve(in: environment)
        let luminance = 0.2126 * c.linearRed + 0.7152 * c.linearGreen + 0.0722 * c.linearBlue
        return luminance > 0.2 ? Color(hex: 0x14171C) : .white
    }

    private var fraction: Double {
        guard let progress, progress.total > 0 else { return 0 }
        return Double(progress.completed) / Double(progress.total)
    }

    private var isRunning: Bool { progress != nil }
    private var isDone: Bool { progress.map { $0.completed == $0.total } ?? false }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        GeometryReader { geo in
            let fillWidth = geo.size.width * fraction

            ZStack(alignment: .leading) {
                shape.fill(PFDesign.surfaceLow)

                label(foreground: PFDesign.onSurface, secondary: PFDesign.onSurfaceVariant)
                    .transaction { $0.animation = nil }

                ZStack(alignment: .leading) {
                    PFDesign.primaryGradient
                    Shimmer()
                    label(foreground: onFill, secondary: onFill.opacity(0.8))
                        .frame(width: geo.size.width, alignment: .leading)
                        .transaction { $0.animation = nil }
                }
                .frame(width: fillWidth, alignment: .leading)
                .clipShape(shape)
                .shadow(color: PFDesign.primary.opacity(isRunning ? 0.45 : 0), radius: 10)
            }
            // Fill grows with a spring; resetting to idle snaps back.
            .animation(isRunning ? .spring(response: 0.55, dampingFraction: 0.82) : nil, value: fraction)
        }
        .frame(height: 48)
        .overlay { shape.strokeBorder(PFDesign.outlineVariant.opacity(0.25), lineWidth: 0.5) }
    }

    private func label(foreground: Color, secondary: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isRunning ? foreground : (isReady ? PFDesign.success : secondary))
            Text(isRunning ? (isDone ? "Done" : "Processing…") : summary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isRunning || isReady ? foreground : secondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            if let progress {
                Text("\(progress.completed) of \(progress.total)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(secondary)
            }
        }
        .padding(.horizontal, 14)
    }

    private var icon: String {
        if isDone { return "checkmark.circle.fill" }
        if isRunning { return "sparkles" }
        return isReady ? "checkmark.circle.fill" : "circle.dashed"
    }
}

/// A soft highlight sweeping left to right, forever.
private struct Shimmer: View {
    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                let period = 1.6
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period) / period
                let band = max(geo.size.width * 0.35, 80)
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: band)
                .offset(x: -band + phase * (geo.size.width + band))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Info row (key-value pair)

struct PFInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFDesign.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PFDesign.onSurface)
        }
    }
}
// MARK: - Preview & Demo

#Preview("PicFacet Design System") {
    VStack(spacing: 24) {
        // Header
        VStack(spacing: 4) {
            Text("Ethereal Workspace")
                .font(.system(size: 28, weight: .semibold))
            Text("native macOS controls, adaptive light and dark surfaces")
                .font(.system(size: 12))
                .foregroundStyle(PFDesign.onSurfaceVariant)
        }
        
        // Card example
        PFCard {
            VStack(alignment: .leading, spacing: 12) {
                PFSectionLabel(text: "Card Example")
                
                Text("This card uses quiet tonal layering, crisp borders, and adaptive colors that hold up in light and dark mode.")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurface)
                
                PFRunBar(summary: "Convert to PNG", progress: (7, 10))

                // Info rows
                PFInfoRow(label: "Design System", value: "Ethereal Workspace")
                PFInfoRow(label: "Material", value: "Native")
                
                // Buttons
                HStack(spacing: 12) {
                    Button("Secondary") { }
                        .pfSecondaryActionStyle()
                    
                    Button("Primary Action") { }
                        .pfPrimaryActionStyle()
                }
            }
        }
    }
    .padding(32)
    .frame(width: 500)
    .background(PFDesign.canvas)
}
