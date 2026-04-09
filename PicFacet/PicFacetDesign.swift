import SwiftUI

/// "Ethereal Workspace" design tokens — see mockups/DESIGN.md.
/// Tonal layering (white-on-white), precision blue accents, ghost borders,
/// pill chips and a gradient primary CTA. Kept intentionally small so the
/// real UI files stay readable.
enum PFDesign {
    // MARK: Surfaces
    static let canvas           = Color(hex: 0xF9F9FB) // surface / base canvas
    static let surfaceLow       = Color(hex: 0xF3F3F5) // recessed
    static let surfaceLowest    = Color(hex: 0xFFFFFF) // elevated card
    static let surfaceHigh      = Color(hex: 0xE8E8EA) // secondary button / unselected chip

    // MARK: Ink
    static let onSurface        = Color(hex: 0x1A1C1D)
    static let onSurfaceVariant = Color(hex: 0x5E6272)
    static let outlineVariant   = Color(hex: 0xC1C6D7)

    // MARK: Accent
    static let primary          = Color(hex: 0x0058BC)
    static let primaryBright    = Color(hex: 0x0070EB)
    static let primaryGradient  = LinearGradient(
        colors: [primary, primaryBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Radii
    static let rCard: CGFloat  = 20
    static let rInner: CGFloat = 14
}

// MARK: - Color hex helper

extension Color {
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

// MARK: - Card container

struct PFCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(22)
            .background(PFDesign.surfaceLowest, in: RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous))
            .overlay(
                // Whisper "ghost border" — outline_variant @ ~15% opacity.
                RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous)
                    .strokeBorder(PFDesign.outlineVariant.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: PFDesign.onSurface.opacity(0.05), radius: 30, x: 0, y: 8)
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

// MARK: - Selection chip (pill)

struct PFChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : PFDesign.onSurface)
                .background {
                    if isSelected {
                        Capsule(style: .continuous).fill(PFDesign.primaryGradient)
                    } else {
                        Capsule(style: .continuous).fill(hovering ? PFDesign.surfaceLow : PFDesign.surfaceHigh)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Primary CTA (gradient pill)

struct PFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(PFDesign.primaryGradient, in: Capsule(style: .continuous))
            .shadow(color: PFDesign.primary.opacity(0.25), radius: 14, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Secondary button (ghost / tertiary)

struct PFSecondaryButtonStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(PFDesign.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PFDesign.surfaceHigh, in: Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
