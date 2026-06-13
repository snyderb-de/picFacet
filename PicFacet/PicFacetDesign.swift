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
    static let chrome           = Color.adaptive(light: 0xFBFCFE, dark: 0x181D23, alpha: 0.86)

    // MARK: Ink
    static let onSurface        = Color.adaptive(light: 0x161A1F, dark: 0xF5F7FA)
    static let onSurfaceVariant = Color.adaptive(light: 0x5D6673, dark: 0xB7C0CC)
    static let outlineVariant   = Color.adaptive(light: 0xBCC6D2, dark: 0x485360)

    // MARK: Accent
    static let primary          = Color.adaptive(light: 0x005BBF, dark: 0x5AA9FF)
    static let primaryBright    = Color.adaptive(light: 0x0078FF, dark: 0x8ECBFF)
    static let success          = Color.adaptive(light: 0x0A7A4B, dark: 0x53D18C)
    static let amber            = Color.adaptive(light: 0x9B5B00, dark: 0xF0B44D)
    static let primaryGradient  = LinearGradient(
        colors: [primary, primaryBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Radii
    static let rCard: CGFloat  = 8
    static let rInner: CGFloat = 8
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

struct PFPanelBackground: ViewModifier {
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                content
                    .background(PFDesign.chrome, in: RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous))
                    .glassEffect(.regular.tint(PFDesign.chrome.opacity(0.34)).interactive(), in: .rect(cornerRadius: PFDesign.rCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous)
                            .strokeBorder(PFDesign.outlineVariant.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 14)
            } else {
                content
                    .background(PFDesign.chrome, in: RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous))
                    .glassEffect(.regular.tint(PFDesign.chrome.opacity(0.34)), in: .rect(cornerRadius: PFDesign.rCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous)
                            .strokeBorder(PFDesign.outlineVariant.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 14)
            }
        } else {
            content
                .background(PFDesign.surfaceLowest,
                          in: RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PFDesign.rCard, style: .continuous)
                        .strokeBorder(PFDesign.outlineVariant.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 26, x: 0, y: 12)
        }
    }
}

extension View {
    func pfPanel(interactive: Bool = false) -> some View {
        modifier(PFPanelBackground(interactive: interactive))
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

// MARK: - Selection chip

struct PFChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String? = nil
    let action: () -> Void

    @State private var hovering = false
    @State private var pressing = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 13)
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

private struct ChipBackgroundModifier: ViewModifier {
    let isSelected: Bool
    let hovering: Bool
    let pressing: Bool
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(PFDesign.primaryGradient) : AnyShapeStyle(hovering ? PFDesign.surfaceLowest : PFDesign.surfaceLow))
            }
            .overlay {
                RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                    .strokeBorder(isSelected ? PFDesign.primaryBright.opacity(0.5) : PFDesign.outlineVariant.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: isSelected ? PFDesign.primary.opacity(pressing ? 0.08 : 0.16) : .clear,
                    radius: pressing ? 3 : 7,
                    x: 0,
                    y: pressing ? 1 : 3)
    }
}

// MARK: - Primary CTA

struct PFPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(PFDesign.primaryGradient, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.22 : 0), lineWidth: 1)
            }
            .shadow(color: PFDesign.primary.opacity(isEnabled ? 0.28 : 0), radius: 14, x: 0, y: 7)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.38)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Secondary button

struct PFSecondaryButtonStyle: ButtonStyle {
    @State private var hovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(PFDesign.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(hovering ? PFDesign.surfaceLowest : PFDesign.surfaceLow,
                        in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous)
                    .strokeBorder(PFDesign.outlineVariant.opacity(0.16), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .onHover { hovering = $0 }
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
                PFInfoRow(label: "Material", value: "Native")
                
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
