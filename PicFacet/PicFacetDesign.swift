import SwiftUI

/// "Ethereal Workspace" design tokens — see mockups/DESIGN.md.
/// Tonal layering (white-on-white), precision blue accents, ghost borders,
/// pill chips and a gradient primary CTA. Kept intentionally small so the
/// real UI files stay readable.
///
/// Now with Liquid Glass support for macOS 15+ and graceful fallback for older versions.
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
    
    // MARK: - Liquid Glass Support
    
    /// Check if Liquid Glass is available (macOS 26.0+)
    @available(macOS 26.0, *)
    static var supportsLiquidGlass: Bool {
        return true
    }
    
    /// Returns true if current OS supports Liquid Glass
    static var canUseLiquidGlass: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }
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

// MARK: - Card container with Liquid Glass

struct PFCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(22)
            .modifier(CardBackgroundModifier())
    }
}

/// Applies Liquid Glass effect on macOS 26+ or falls back to traditional design
private struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // Modern Liquid Glass effect
            content
                .glassEffect(.regular.tint(PFDesign.primary.opacity(0.03)), 
                           in: .rect(cornerRadius: PFDesign.rCard))
                .shadow(color: PFDesign.onSurface.opacity(0.08), radius: 40, x: 0, y: 12)
        } else {
            // Fallback: Original white card with ghost border
            content
                .background(PFDesign.surfaceLowest, 
                          in: RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous)
                        .strokeBorder(PFDesign.outlineVariant.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: PFDesign.onSurface.opacity(0.05), radius: 30, x: 0, y: 8)
        }
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

// MARK: - Selection chip (pill) with Liquid Glass

struct PFChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false
    @State private var pressing = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : PFDesign.onSurface)
                .modifier(ChipBackgroundModifier(isSelected: isSelected, 
                                                hovering: hovering, 
                                                pressing: pressing))
                .scaleEffect(pressing ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: pressing)
                .animation(.easeInOut(duration: 0.15), value: hovering)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false }
        )
        .onHover { hovering = $0 }
    }
}

/// Chip background with Liquid Glass support
private struct ChipBackgroundModifier: ViewModifier {
    let isSelected: Bool
    let hovering: Bool
    let pressing: Bool
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // Modern Liquid Glass chips
            if isSelected {
                content
                    .background {
                        Capsule(style: .continuous)
                            .fill(PFDesign.primaryGradient)
                    }
                    .glassEffect(.regular.tint(PFDesign.primary.opacity(0.15)).interactive(), 
                               in: .capsule)
                    .shadow(color: PFDesign.primary.opacity(pressing ? 0.15 : 0.25), 
                           radius: pressing ? 6 : 12, x: 0, y: pressing ? 2 : 6)
            } else {
                content
                    .background {
                        Capsule(style: .continuous)
                            .fill(hovering ? PFDesign.surfaceLow : PFDesign.surfaceHigh)
                    }
                    .glassEffect(.regular.interactive(hovering), in: .capsule)
            }
        } else {
            // Fallback: Original design
            content
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(PFDesign.primaryGradient)
                            .shadow(color: PFDesign.primary.opacity(pressing ? 0.1 : 0.2), 
                                   radius: pressing ? 4 : 8, x: 0, y: pressing ? 2 : 4)
                    } else {
                        Capsule(style: .continuous)
                            .fill(hovering ? PFDesign.surfaceLow : PFDesign.surfaceHigh)
                    }
                }
        }
    }
}

// MARK: - Primary CTA (gradient pill) with Liquid Glass

struct PFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            // Modern Liquid Glass button
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    Capsule(style: .continuous)
                        .fill(PFDesign.primaryGradient)
                }
                .glassEffect(.regular.tint(PFDesign.primaryBright.opacity(0.2)).interactive(), 
                           in: .capsule)
                .shadow(color: PFDesign.primary.opacity(0.3), radius: 18, x: 0, y: 8)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        } else {
            // Fallback: Original design
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
}

// MARK: - Secondary button (ghost / tertiary) with Liquid Glass

struct PFSecondaryButtonStyle: ButtonStyle {
    @State private var hovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            // Modern Liquid Glass secondary button
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PFDesign.onSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    Capsule(style: .continuous)
                        .fill(PFDesign.surfaceHigh)
                }
                .glassEffect(.regular.interactive(hovering), in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovering = $0 }
        } else {
            // Fallback: Original design
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PFDesign.onSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PFDesign.surfaceHigh, in: Capsule(style: .continuous))
                .opacity(configuration.isPressed ? 0.85 : 1)
                .onHover { hovering = $0 }
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
                    .buttonStyle(PFSecondaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Progress indicator

struct PFProgressView: View {
    let current: Int
    let total: Int
    
    var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule(style: .continuous)
                        .fill(PFDesign.surfaceLow)
                        .frame(height: 6)
                    
                    // Fill
                    Capsule(style: .continuous)
                        .fill(PFDesign.primaryGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            
            // Label
            HStack {
                Text("Processing images…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                Spacer()
                Text("\(current) of \(total)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PFDesign.primary)
            }
        }
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

#Preview("Liquid Glass Design System") {
    VStack(spacing: 24) {
        // Header
        VStack(spacing: 4) {
            Text("Ethereal Workspace")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.5)
            Text("with Liquid Glass on macOS 15+")
                .font(.system(size: 12))
                .foregroundStyle(PFDesign.onSurfaceVariant)
        }
        
        // Card example
        PFCard {
            VStack(alignment: .leading, spacing: 12) {
                PFSectionLabel(text: "Card Example")
                
                Text("This card uses Liquid Glass on macOS 15+ for a fluid, modern look. On older versions, it falls back to a beautiful white card with ghost borders.")
                    .font(.system(size: 12))
                    .foregroundStyle(PFDesign.onSurface)
                
                // Chips
                HStack(spacing: 8) {
                    PFChip(title: "Selected", isSelected: true) { }
                    PFChip(title: "Option 2", isSelected: false) { }
                    PFChip(title: "Option 3", isSelected: false) { }
                }
                
                // Progress example
                PFProgressView(current: 7, total: 10)
                
                // Info rows
                PFInfoRow(label: "Design System", value: "Ethereal Workspace")
                PFInfoRow(label: "Material", value: PFDesign.canUseLiquidGlass ? "Liquid Glass" : "Classic")
                
                // Buttons
                HStack(spacing: 12) {
                    Button("Secondary") { }
                        .buttonStyle(PFSecondaryButtonStyle())
                    
                    Button("Primary Action") { }
                        .buttonStyle(PFPrimaryButtonStyle())
                }
            }
        }
    }
    .padding(32)
    .frame(width: 500)
    .background(PFDesign.canvas)
}

