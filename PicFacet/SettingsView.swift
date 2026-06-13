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
    @State private var defaultFormat: ImageFormat = PicFacetSettings.shared.defaultFormat
    @State private var defaultResizePercent: Int = PicFacetSettings.shared.defaultResizePercent
    @State private var defaultDPI: Int = PicFacetSettings.shared.defaultDPI

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
                    .onChange(of: appearance) { v in
                        PicFacetSettings.shared.appAppearance = v
                        applyAppearance(v)
                    }
                } label: {
                    Text("Appearance")
                    Text("Choose a light or dark tint for the workspace.")
                }
            }
            
            Section("Defaults") {
                LabeledContent {
                    Picker("", selection: $defaultFormat) {
                        ForEach(ImageFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: defaultFormat) { PicFacetSettings.shared.defaultFormat = $0 }
                } label: {
                    Text("Default format")
                    Text("Pre-selected format in the converter.")
                }
                
                LabeledContent {
                    Picker("", selection: $defaultResizePercent) {
                        Text("25%").tag(25)
                        Text("50%").tag(50)
                        Text("75%").tag(75)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: defaultResizePercent) { PicFacetSettings.shared.defaultResizePercent = $0 }
                } label: {
                    Text("Default resize")
                    Text("Pre-selected resize percentage.")
                }
                
                LabeledContent {
                    Picker("", selection: $defaultDPI) {
                        ForEach(PicFacetSettings.dpiOptions, id: \.self) { dpi in
                            Text("\(dpi) DPI").tag(dpi)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    .onChange(of: defaultDPI) { PicFacetSettings.shared.defaultDPI = $0 }
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
                .onChange(of: overwriteSource) { PicFacetSettings.shared.overwriteSource = $0 }

                Toggle(isOn: $onlyIfSmaller) {
                    Text("Keep converted file only if smaller")
                    Text("Discard the new file when it isn't a size win.")
                }
                .onChange(of: onlyIfSmaller) { PicFacetSettings.shared.onlyIfSmaller = $0 }

                Toggle(isOn: $deleteOriginalAfterConvert) {
                    Text("Delete original after conversion")
                    Text("Remove the source file once the new one is saved.")
                }
                .onChange(of: deleteOriginalAfterConvert) { PicFacetSettings.shared.deleteOriginalAfterConvert = $0 }
            }

            Section("Resize") {
                Toggle(isOn: $isProportional) {
                    Text("Keep proportions by default")
                    Text("Lock the aspect ratio when resizing.")
                }
                .onChange(of: isProportional) { PicFacetSettings.shared.isProportional = $0 }
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 680)
    }

    private func applyAppearance(_ value: PicFacetSettings.AppAppearance) {
        switch value {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
