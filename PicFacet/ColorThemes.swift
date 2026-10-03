import SwiftUI

/// Every surface, ink and status colour for one appearance of a theme.
struct Palette {
    var canvas: UInt32
    var surfaceLow: UInt32
    var surfaceLowest: UInt32
    var surfaceHigh: UInt32
    var chrome: UInt32
    var onSurface: UInt32
    var onSurfaceVariant: UInt32
    var outlineVariant: UInt32
    var accent: UInt32
    var success: UInt32
    var amber: UInt32
}

/// A named colour scheme with a light and a dark palette, so the light/dark
/// toggle keeps working inside every theme. "default" is PicFacet's own look.
struct ColorTheme: Identifiable {
    let id: String
    let name: String
    let light: Palette
    let dark: Palette

    static let defaultID = "default"

    static func theme(id: String) -> ColorTheme {
        all.first { $0.id == id } ?? all[0]
    }

    static let all: [ColorTheme] = [
        ColorTheme(
            id: defaultID, name: "PicFacet",
            light: Palette(canvas: 0xF6F7F9, surfaceLow: 0xECEFF3, surfaceLowest: 0xFFFFFF, surfaceHigh: 0xDDE3EA,
                           chrome: 0xFBFCFE, onSurface: 0x161A1F, onSurfaceVariant: 0x5D6673, outlineVariant: 0xBCC6D2,
                           accent: 0x005BBF, success: 0x0A7A4B, amber: 0x9B5B00),
            dark: Palette(canvas: 0x111418, surfaceLow: 0x1B2026, surfaceLowest: 0x242A32, surfaceHigh: 0x303842,
                          chrome: 0x181D23, onSurface: 0xF5F7FA, onSurfaceVariant: 0xB7C0CC, outlineVariant: 0x485360,
                          accent: 0x5AA9FF, success: 0x53D18C, amber: 0xF0B44D)
        ),
        ColorTheme(
            id: "dracula", name: "Dracula",
            light: Palette(canvas: 0xFFFBEB, surfaceLow: 0xF3EEDA, surfaceLowest: 0xFFFFFF, surfaceHigh: 0xDEDCCB,
                           chrome: 0xFFFBEB, onSurface: 0x1F1F1F, onSurfaceVariant: 0x6C664B, outlineVariant: 0xCFCBB0,
                           accent: 0x644AC9, success: 0x14710A, amber: 0xA3144D),
            dark: Palette(canvas: 0x21222C, surfaceLow: 0x282A36, surfaceLowest: 0x343746, surfaceHigh: 0x44475A,
                          chrome: 0x282A36, onSurface: 0xF8F8F2, onSurfaceVariant: 0xAEB5D6, outlineVariant: 0x565A75,
                          accent: 0xBD93F9, success: 0x50FA7B, amber: 0xFFB86C)
        ),
        ColorTheme(
            id: "onedark", name: "One Dark",
            light: Palette(canvas: 0xFAFAFA, surfaceLow: 0xF0F0F1, surfaceLowest: 0xFFFFFF, surfaceHigh: 0xE5E5E6,
                           chrome: 0xFAFAFA, onSurface: 0x383A42, onSurfaceVariant: 0x696C77, outlineVariant: 0xD0D1D6,
                           accent: 0x4078F2, success: 0x3E8C3D, amber: 0xA67200),
            dark: Palette(canvas: 0x21252B, surfaceLow: 0x282C34, surfaceLowest: 0x2F3541, surfaceHigh: 0x3E4451,
                          chrome: 0x282C34, onSurface: 0xD7DAE0, onSurfaceVariant: 0x9DA5B4, outlineVariant: 0x4B5263,
                          accent: 0x61AFEF, success: 0x98C379, amber: 0xE5C07B)
        ),
        ColorTheme(
            id: "nord", name: "Nord",
            light: Palette(canvas: 0xECEFF4, surfaceLow: 0xE5E9F0, surfaceLowest: 0xFFFFFF, surfaceHigh: 0xD8DEE9,
                           chrome: 0xECEFF4, onSurface: 0x2E3440, onSurfaceVariant: 0x4C566A, outlineVariant: 0xC2CAD8,
                           accent: 0x5E81AC, success: 0x4F7A38, amber: 0xA87B1F),
            dark: Palette(canvas: 0x2E3440, surfaceLow: 0x3B4252, surfaceLowest: 0x434C5E, surfaceHigh: 0x4C566A,
                          chrome: 0x3B4252, onSurface: 0xECEFF4, onSurfaceVariant: 0xB4BFD1, outlineVariant: 0x5E6B82,
                          accent: 0x88C0D0, success: 0xA3BE8C, amber: 0xEBCB8B)
        ),
        ColorTheme(
            id: "solarized", name: "Solarized",
            light: Palette(canvas: 0xFDF6E3, surfaceLow: 0xEEE8D5, surfaceLowest: 0xFFFCF0, surfaceHigh: 0xE2DBC2,
                           chrome: 0xFDF6E3, onSurface: 0x073642, onSurfaceVariant: 0x586E75, outlineVariant: 0xCEC7AC,
                           accent: 0x1E7DBF, success: 0x6E7F00, amber: 0x9A7400),
            dark: Palette(canvas: 0x002B36, surfaceLow: 0x073642, surfaceLowest: 0x0D4655, surfaceHigh: 0x15505F,
                          chrome: 0x073642, onSurface: 0xEEE8D5, onSurfaceVariant: 0x93A1A1, outlineVariant: 0x2F6270,
                          accent: 0x268BD2, success: 0x859900, amber: 0xB58900)
        ),
        ColorTheme(
            id: "gruvbox", name: "Gruvbox",
            light: Palette(canvas: 0xF9F5D7, surfaceLow: 0xFBF1C7, surfaceLowest: 0xFFFBEA, surfaceHigh: 0xEBDBB2,
                           chrome: 0xF9F5D7, onSurface: 0x3C3836, onSurfaceVariant: 0x7C6F64, outlineVariant: 0xD5C4A1,
                           accent: 0xAF3A03, success: 0x79740E, amber: 0xB57614),
            dark: Palette(canvas: 0x1D2021, surfaceLow: 0x282828, surfaceLowest: 0x3C3836, surfaceHigh: 0x504945,
                          chrome: 0x282828, onSurface: 0xEBDBB2, onSurfaceVariant: 0xA89984, outlineVariant: 0x665C54,
                          accent: 0xFE8019, success: 0xB8BB26, amber: 0xFABD2F)
        ),
    ]
}

extension Color {
    /// One palette field for the light and dark appearance of the active theme.
    static func themed(_ keyPath: KeyPath<Palette, UInt32>, alpha: Double = 1) -> Color {
        let theme = Theme.shared.colorTheme
        return .adaptive(light: theme.light[keyPath: keyPath], dark: theme.dark[keyPath: keyPath], alpha: alpha)
    }
}
