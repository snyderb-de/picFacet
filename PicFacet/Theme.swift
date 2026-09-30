import AppKit
import SwiftUI
import PicFacetCore

/// User-chosen accent colour and window background. Views read it through
/// `PFDesign.primary` / `PFDesign.backdrop`, and Observation re-renders them
/// when Settings changes it.
@Observable final class Theme {
    static let shared = Theme()

    /// Preset name or "#RRGGBB". See `PicFacetSettings.accentColor`.
    var accentID: String {
        didSet { PicFacetSettings.shared.accentColor = accentID }
    }

    /// Preset name or "#RRGGBB,#RRGGBB". See `PicFacetSettings.backdrop`.
    var backdropID: String {
        didSet { PicFacetSettings.shared.backdrop = backdropID }
    }

    private init() {
        accentID = PicFacetSettings.shared.accentColor
        backdropID = PicFacetSettings.shared.backdrop
    }

    var accent: Color {
        if let preset = AccentPreset.all.first(where: { $0.id == accentID }) { return preset.color }
        return Color(hexString: accentID) ?? AccentPreset.all[0].color
    }

    /// Colours washed over the canvas, strongest first. Empty for a plain canvas.
    var backdropColors: [Color] {
        if backdropID == "accent" { return [accent, accent.opacity(0.35)] }
        if let preset = BackdropPreset.all.first(where: { $0.id == backdropID }) { return preset.colors }
        let colors = backdropID.split(separator: ",").compactMap { Color(hexString: String($0)) }
        return colors.count == 2 ? colors : []
    }

    /// The two custom backdrop colours, falling back to the current ones.
    var customBackdrop: (Color, Color) {
        let colors = backdropColors
        return colors.count == 2 ? (colors[0], colors[1]) : (accent, accent)
    }
}

struct AccentPreset: Identifiable {
    let id: String
    let name: String
    let color: Color

    static let all: [AccentPreset] = [
        AccentPreset(id: "blue", name: "Blue", color: .adaptive(light: 0x005BBF, dark: 0x5AA9FF)),
        AccentPreset(id: "purple", name: "Purple", color: .adaptive(light: 0x6E3FD1, dark: 0xB18CFF)),
        AccentPreset(id: "pink", name: "Pink", color: .adaptive(light: 0xC2185B, dark: 0xFF7EB6)),
        AccentPreset(id: "red", name: "Red", color: .adaptive(light: 0xC62828, dark: 0xFF7B72)),
        AccentPreset(id: "orange", name: "Orange", color: .adaptive(light: 0xC25E00, dark: 0xFFA657)),
        AccentPreset(id: "yellow", name: "Yellow", color: .adaptive(light: 0x9A7400, dark: 0xF2CC60)),
        AccentPreset(id: "green", name: "Green", color: .adaptive(light: 0x1A7F37, dark: 0x56D364)),
        AccentPreset(id: "teal", name: "Teal", color: .adaptive(light: 0x00796B, dark: 0x4DD0C4)),
        AccentPreset(id: "graphite", name: "Graphite", color: .adaptive(light: 0x57606A, dark: 0xAEB6C0)),
        AccentPreset(id: "system", name: "System accent", color: .accentColor),
    ]
}

struct BackdropPreset: Identifiable {
    let id: String
    let name: String
    let colors: [Color]

    /// "accent" is resolved by `Theme` because it follows the accent colour.
    static let all: [BackdropPreset] = [
        BackdropPreset(id: "accent", name: "Accent", colors: []),
        BackdropPreset(id: "ocean", name: "Ocean", colors: [Color(hex: 0x2F80ED), Color(hex: 0x56CCF2)]),
        BackdropPreset(id: "sunset", name: "Sunset", colors: [Color(hex: 0xFF6B6B), Color(hex: 0xFFB347)]),
        BackdropPreset(id: "aurora", name: "Aurora", colors: [Color(hex: 0x7F5AF0), Color(hex: 0x2CB67D)]),
        BackdropPreset(id: "rose", name: "Rose", colors: [Color(hex: 0xF472B6), Color(hex: 0xA78BFA)]),
        BackdropPreset(id: "ember", name: "Ember", colors: [Color(hex: 0xF97316), Color(hex: 0xDB2777)]),
        BackdropPreset(id: "graphite", name: "Graphite", colors: [Color(hex: 0x6B7280), Color(hex: 0x9CA3AF)]),
        BackdropPreset(id: "none", name: "None", colors: []),
    ]
}

extension Color {
    /// Parses "#RRGGBB".
    init?(hexString: String) {
        let digits = hexString.trimmingCharacters(in: .whitespaces).drop { $0 == "#" }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(hex: value)
    }

    /// "#RRGGBB" in sRGB, resolved for the current appearance.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
