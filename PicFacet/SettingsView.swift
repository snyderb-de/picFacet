import AppKit
import SwiftUI
import PicFacetCore

/// Settings window built with SwiftUI's native grouped Form — this is the
/// same machinery System Settings uses, so we get Apple's cards, spacing,
/// separators, typography and material for free. We intentionally do NOT
/// hand-roll cards here: the mockup aesthetic is copying System Settings,
/// so the closer-to-Apple move is to let the framework draw it.
struct SettingsView: View {
    @State private var appearance: PicFacetSettings.AppAppearance = PicFacetSettings.shared.appAppearance
    @State private var overwriteSource: Bool = PicFacetSettings.shared.overwriteSource
    @State private var onlyIfSmaller: Bool = PicFacetSettings.shared.onlyIfSmaller
    @State private var deleteOriginalAfterConvert: Bool = PicFacetSettings.shared.deleteOriginalAfterConvert
    @State private var isProportional: Bool = PicFacetSettings.shared.isProportional
    @State private var defaultFormat: ImageFormat? = PicFacetSettings.shared.defaultFormat
    @State private var defaultResizePercent: Int? = PicFacetSettings.shared.defaultResizePercent
    @State private var defaultDPI: Int? = PicFacetSettings.shared.defaultDPI

    var body: some View {
        Form {
            // Header with app icon/name
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundStyle(PFDesign.primary)
                    Text("PicFacet")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PFDesign.onSurface)
                    Text("Image processing from anywhere")
                        .font(.system(size: 12))
                        .foregroundStyle(PFDesign.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Section("General") {
                LabeledContent {
                    Picker("", selection: $appearance) {
                        Text("System").tag(PicFacetSettings.AppAppearance.system)
                        Text("Light").tag(PicFacetSettings.AppAppearance.light)
                        Text("Dark").tag(PicFacetSettings.AppAppearance.dark)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .onChange(of: appearance) { _, v in
                        PicFacetSettings.shared.appAppearance = v
                        applyAppearance(v)
                    }
                } label: {
                    Text("Appearance")
                    Text("Choose a light or dark tint for the workspace.")
                }
            }
            
            Section("Theme") {
                VStack(alignment: .leading, spacing: 10) {
                    settingLabel("Accent color", "Buttons, highlights and the progress bar.")
                    HStack(spacing: 8) {
                        ForEach(AccentPreset.all) { preset in
                            Swatch(isSelected: theme.accentID == preset.id, help: preset.name, circular: true) {
                                Circle().fill(preset.color)
                            } action: {
                                theme.accentID = preset.id
                            }
                        }
                        Divider().frame(height: 18)
                        ColorPicker("Custom", selection: Binding(
                            get: { theme.accent },
                            set: { theme.accentID = $0.hexString }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .help("Custom color")
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 10) {
                    settingLabel("Background", "Gradient behind the Batch and Chooser windows.")
                    HStack(spacing: 8) {
                        ForEach(BackdropPreset.all) { preset in
                            Swatch(isSelected: theme.backdropID == preset.id, help: preset.name) {
                                backdropSwatch(preset)
                            } action: {
                                theme.backdropID = preset.id
                            }
                        }
                        Divider().frame(height: 18)
                        ColorPicker("From", selection: customBackdrop(first: true), supportsOpacity: false)
                            .labelsHidden()
                            .help("Custom gradient: first color")
                        ColorPicker("To", selection: customBackdrop(first: false), supportsOpacity: false)
                            .labelsHidden()
                            .help("Custom gradient: second color")
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Defaults") {
                LabeledContent {
                    Picker("", selection: $defaultFormat) {
                        Text("No Change").tag(nil as ImageFormat?)
                        ForEach(ImageFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(Optional(format))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: defaultFormat) { _, new in PicFacetSettings.shared.defaultFormat = new }
                } label: {
                    Text("Default format")
                    Text("Pre-selected format in the converter.")
                }
                
                LabeledContent {
                    Picker("", selection: $defaultResizePercent) {
                        Text("No Change").tag(nil as Int?)
                        ForEach(ResizeMode.presetPercents, id: \.self) { percent in
                            Text("\(percent)%").tag(Optional(percent))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: defaultResizePercent) { _, new in PicFacetSettings.shared.defaultResizePercent = new }
                } label: {
                    Text("Default resize")
                    Text("Pre-selected resize percentage.")
                }
                
                LabeledContent {
                    Picker("", selection: $defaultDPI) {
                        Text("No Change").tag(nil as Int?)
                        ForEach(PicFacetSettings.dpiOptions, id: \.self) { dpi in
                            Text("\(dpi) DPI").tag(Optional(dpi))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: defaultDPI) { _, new in PicFacetSettings.shared.defaultDPI = new }
                } label: {
                    Text("Default DPI")
                    Text("Pre-selected DPI setting.")
                }
            }

            Section("Processing") {
                Toggle(isOn: $overwriteSource) {
                    Text("Overwrite source files")
                    Text("Replace the original instead of writing alongside it.")
                }
                .onChange(of: overwriteSource) { _, new in PicFacetSettings.shared.overwriteSource = new }

                Toggle(isOn: $onlyIfSmaller) {
                    Text("Keep result only if smaller")
                    Text("Discard a converted or resized file when it isn't smaller than the original. DPI-only changes are always kept.")
                }
                .onChange(of: onlyIfSmaller) { _, new in PicFacetSettings.shared.onlyIfSmaller = new }

                Toggle(isOn: $deleteOriginalAfterConvert) {
                    Text("Delete original after conversion")
                    Text("Remove the source file once the new one is saved.")
                }
                .onChange(of: deleteOriginalAfterConvert) { _, new in PicFacetSettings.shared.deleteOriginalAfterConvert = new }
            }

            Section("Resize") {
                Toggle(isOn: $isProportional) {
                    Text("Keep proportions by default")
                    Text("Lock the aspect ratio when resizing.")
                }
                .onChange(of: isProportional) { _, new in PicFacetSettings.shared.isProportional = new }
            }
        }
        .formStyle(.grouped)
        .tint(PFDesign.primary)
        .frame(width: 580, height: 680)
    }

    private var theme: Theme { Theme.shared }

    private func settingLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func backdropSwatch(_ preset: BackdropPreset) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        switch preset.id {
        case "none":
            shape.fill(PFDesign.canvas)
                .overlay { Image(systemName: "slash.circle").font(.system(size: 11)).foregroundStyle(.secondary) }
        case "accent":
            shape.fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.35)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            shape.fill(LinearGradient(colors: preset.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private func customBackdrop(first: Bool) -> Binding<Color> {
        Binding(
            get: { first ? theme.customBackdrop.0 : theme.customBackdrop.1 },
            set: { color in
                let (a, b) = theme.customBackdrop
                theme.backdropID = first ? "\(color.hexString),\(b.hexString)" : "\(a.hexString),\(color.hexString)"
            }
        )
    }

    private func applyAppearance(_ value: PicFacetSettings.AppAppearance) {
        switch value {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// A selectable colour sample with a ring when chosen.
private struct Swatch<Fill: View>: View {
    let isSelected: Bool
    let help: String
    var circular = false
    @ViewBuilder let fill: () -> Fill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            fill()
                .frame(width: 22, height: 22)
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: circular ? 14 : 9, style: .continuous)
                        .strokeBorder(isSelected ? Color.primary.opacity(0.7) : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
