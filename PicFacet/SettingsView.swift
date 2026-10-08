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
    @State private var saveUnsupportedAsJPEG: Bool = PicFacetSettings.shared.saveUnsupportedAsJPEG
    @State private var isProportional: Bool = PicFacetSettings.shared.isProportional
    @State private var defaultFormat: ImageFormat? = PicFacetSettings.shared.defaultFormat
    @State private var defaultResizePercent: Int? = PicFacetSettings.shared.defaultResizePercent
    @State private var defaultDPI: Int? = PicFacetSettings.shared.defaultDPI
    @State private var notifyAfterRuns: Bool = PicFacetSettings.shared.notifyAfterRuns
    @State private var recipes: [Recipe] = RecipeStore.all
    @State private var watchedFolders: [WatchedFolder] = PicFacetSettings.shared.watchedFolders
    @State private var watchInBackground: Bool = PicFacetSettings.shared.watchInBackground
    @State private var backgroundStatus = BackgroundWatching.status
    @State private var backgroundError: String?
    @State private var isConfirmingDelete = false

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
                        if v != PicFacetSettings.shared.appAppearance { AppearanceController.set(v) }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .picFacetAppearanceChanged)) { _ in
                        appearance = PicFacetSettings.shared.appAppearance
                    }
                } label: {
                    Text("Appearance")
                    Text("Choose a light or dark tint for the workspace.")
                }
            }
            
            Section("Theme") {
                VStack(alignment: .leading, spacing: 10) {
                    settingLabel("Color theme", "Surfaces, text and accent. Each has a light and a dark version.")
                    HStack(spacing: 10) {
                        ForEach(ColorTheme.all) { colorTheme in
                            ThemeChip(colorTheme: colorTheme, isSelected: theme.colorThemeID == colorTheme.id) {
                                theme.select(colorTheme: colorTheme.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 10) {
                    settingLabel("Accent color", "Buttons, highlights and the progress bar.")
                    HStack(spacing: 8) {
                        Swatch(isSelected: theme.accentID == Theme.themeAccentID, help: "Theme accent", circular: true) {
                            Circle().fill(Color.themed(\.accent))
                        } action: {
                            theme.accentID = Theme.themeAccentID
                        }
                        Divider().frame(height: 18)
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

            Section("File Access") {
                LabeledContent {
                    Button("Allow Folder Access") { FileAccess.requestCommonFolders() }
                } label: {
                    Text("Common folders")
                    Text("Ask macOS now for Desktop, Documents and Downloads, so the first right-click doesn't stall on a prompt.")
                }

                LabeledContent {
                    Button("Open Full Disk Access…") { FileAccess.openFullDiskAccessSettings() }
                } label: {
                    Text("Every folder and drive")
                    Text("Add PicFacet under Full Disk Access to cover external and network drives too.")
                }
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

                Toggle(isOn: $saveUnsupportedAsJPEG) {
                    Text("Save unsupported formats as JPEG")
                    Text("RAW, ICO, PSD and other formats PicFacet can read but not write. When resizing or changing DPI, save a JPEG beside the original instead of skipping the file. Choosing a Convert format always works.")
                }
                .onChange(of: saveUnsupportedAsJPEG) { _, new in PicFacetSettings.shared.saveUnsupportedAsJPEG = new }
            }

            Section("Resize") {
                Toggle(isOn: $isProportional) {
                    Text("Keep proportions by default")
                    Text("Lock the aspect ratio when resizing.")
                }
                .onChange(of: isProportional) { _, new in PicFacetSettings.shared.isProportional = new }
            }

            Section {
                if recipes.isEmpty {
                    Text("Set up options in the Chooser or Batch window, then choose Recipes → Save Current as Recipe…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                ForEach(recipes) { recipe in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("", text: recipeName(recipe.id), prompt: Text("Recipe name"))
                                .labelsHidden()
                                .multilineTextAlignment(.leading)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium))
                            Text(recipe.selection.summary)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(role: .destructive) { RecipeStore.delete(recipe.id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Delete recipe")
                    }
                }
            } header: {
                Text("Recipes")
            } footer: {
                Text("Recipes appear in the Chooser, the Batch window, Finder's PicFacet menu (with the Finder extension on) and the Shortcuts app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(watchedFolders) { folder in
                    VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Toggle("Watch \(folder.url.lastPathComponent)", isOn: folderEnabled(folder.id))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.url.lastPathComponent)
                                .font(.system(size: 13, weight: .medium))
                            Text(folder.path)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        // Several recipes: each makes its own output from the original.
                        Menu {
                            ForEach(recipes) { recipe in
                                Toggle(recipe.name, isOn: folderUsesRecipe(folder.id, recipe.id))
                            }
                        } label: {
                            Text(recipeSummary(folder))
                                .lineLimit(1)
                        }
                        .frame(width: 150)
                        .help("Recipes to run on each new image. With more than one, each saves to its own folder inside “\(WatchedFolder.outputFolderName)”.")
                        Button(role: .destructive) {
                            PicFacetSettings.shared.setWatchSnapshot(nil, for: folder.id)
                            updateFolders { $0.removeAll { $0.id == folder.id } }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Stop watching")
                    }
                    // String title, so VoiceOver and UI scripting see the name.
                    Toggle("Delete originals after processing", isOn: folderDeletesOriginals(folder.id))
                        .font(.system(size: 11))
                        .foregroundStyle(folder.deleteOriginals ? Color.red : .secondary)
                        .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .padding(.leading, 46)
                    }
                }
                Button("Add Folder…", action: addWatchedFolder)
                    .disabled(recipes.isEmpty)

                if !watchedFolders.isEmpty {
                    Toggle(isOn: $watchInBackground) {
                        Text("Keep watching when PicFacet is closed")
                        Text(backgroundDetail)
                    }
                    .onChange(of: watchInBackground) { _, new in setBackground(new) }

                    if watchInBackground && backgroundStatus == .requiresApproval {
                        Button("Open Login Items…") { BackgroundWatching.openLoginItemsSettings() }
                    }
                }
            } header: {
                Text("Watched Folders")
            } footer: {
                Text(recipes.isEmpty
                     ? "Save a recipe first. New images in a watched folder are run through its recipe."
                     : "New images dropped in a watched folder are run through its recipe. Results go to a “\(WatchedFolder.outputFolderName)” subfolder (one folder per recipe when a folder runs several); originals are kept unless you choose to delete them, and then only after every recipe has saved its result. Images added while nothing was watching are processed the next time watching starts.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle(isOn: $notifyAfterRuns) {
                    Text("Show a summary after background runs")
                    Text("After a Quick Action, Finder recipe or watched folder, show how many files were saved and the space saved.")
                }
                .onChange(of: notifyAfterRuns) { _, new in PicFacetSettings.shared.notifyAfterRuns = new }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // The user may have approved the login item in System Settings.
            backgroundStatus = BackgroundWatching.status
            FolderWatchController.shared.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .picFacetRecipesChanged)) { _ in
            recipes = RecipeStore.all
            watchedFolders = PicFacetSettings.shared.watchedFolders
            FolderWatchController.shared.reload()
        }
        .formStyle(.grouped)
        .tint(PFDesign.primary)
        .frame(width: 580, height: 680)
    }

    private var theme: Theme { Theme.shared }

    // MARK: Recipes & watched folders

    private func recipeName(_ id: UUID) -> Binding<String> {
        Binding(
            get: { recipes.first { $0.id == id }?.name ?? "" },
            set: { name in
                guard var recipe = recipes.first(where: { $0.id == id }) else { return }
                recipe.name = name
                RecipeStore.update(recipe)
            }
        )
    }

    private func updateFolders(_ change: (inout [WatchedFolder]) -> Void) {
        change(&watchedFolders)
        PicFacetSettings.shared.watchedFolders = watchedFolders
        FolderWatchController.shared.reload()
    }

    private var backgroundDetail: String {
        if let backgroundError { return backgroundError }
        guard watchInBackground else {
            return "Runs a small background helper that starts at login, so folders are watched even after you quit PicFacet."
        }
        switch backgroundStatus {
        case .enabled: return "Watching in the background. The PicFacet Watcher helper starts at login."
        case .requiresApproval: return "Allow “PicFacet Watcher” under System Settings → General → Login Items. Until then, folders are watched only while PicFacet is open."
        default: return "The background helper isn't running. Folders are watched only while PicFacet is open."
        }
    }

    private func setBackground(_ enabled: Bool) {
        guard enabled != PicFacetSettings.shared.watchInBackground else { return }
        do {
            try BackgroundWatching.setEnabled(enabled)
            backgroundError = nil
        } catch {
            backgroundError = "Couldn't start the background helper: \(error.localizedDescription)"
            watchInBackground = false
        }
        backgroundStatus = BackgroundWatching.status
    }

    private func folderEnabled(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { watchedFolders.first { $0.id == id }?.isEnabled ?? false },
            set: { value in
                // Switched back on: start fresh rather than process everything added meanwhile.
                if value { FolderWatchController.shared.resetHistory(id) }
                updateFolders { folders in
                    if let i = folders.firstIndex(where: { $0.id == id }) { folders[i].isEnabled = value }
                }
            }
        )
    }

    /// Turning deletion on asks first: originals are removed permanently.
    private func folderDeletesOriginals(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { watchedFolders.first { $0.id == id }?.deleteOriginals ?? false },
            set: { value in
                guard value else { return setDeleteOriginals(false, for: id) }
                // Ask outside the binding update, once: a modal run from inside
                // SwiftUI's setter can be re-entered by further clicks.
                guard !isConfirmingDelete else { return }
                isConfirmingDelete = true
                DispatchQueue.main.async {
                    if confirmDeleteOriginals(for: id) { setDeleteOriginals(true, for: id) }
                    isConfirmingDelete = false
                }
            }
        )
    }

    private func setDeleteOriginals(_ value: Bool, for id: UUID) {
        updateFolders { folders in
            if let i = folders.firstIndex(where: { $0.id == id }) { folders[i].deleteOriginals = value }
        }
    }

    private func confirmDeleteOriginals(for id: UUID) -> Bool {
        let name = watchedFolders.first { $0.id == id }?.url.lastPathComponent ?? "this folder"
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Permanently delete originals in “\(name)”?"
        alert.informativeText = "After each image is processed into “\(WatchedFolder.outputFolderName)”, the file you dropped in is deleted permanently. It does not go to the Trash and can't be recovered.\n\nA file is deleted only after every recipe for this folder has saved its result. If any recipe fails, or a result is discarded because it wasn't smaller, the original stays."
        alert.addButton(withTitle: "Delete Originals")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// "Blog" or "Blog + 2 more".
    private func recipeSummary(_ folder: WatchedFolder) -> String {
        let names = folder.recipeIDs.compactMap { id in recipes.first { $0.id == id }?.name }
        guard let first = names.first else { return "Choose recipes" }
        return names.count == 1 ? first : "\(first) + \(names.count - 1) more"
    }

    /// Adds or removes a recipe; the last one can't be removed.
    private func folderUsesRecipe(_ folderID: UUID, _ recipeID: UUID) -> Binding<Bool> {
        Binding(
            get: { watchedFolders.first { $0.id == folderID }?.recipeIDs.contains(recipeID) ?? false },
            set: { value in updateFolders { folders in
                guard let i = folders.firstIndex(where: { $0.id == folderID }) else { return }
                if value {
                    if !folders[i].recipeIDs.contains(recipeID) { folders[i].recipeIDs.append(recipeID) }
                } else if folders[i].recipeIDs.count > 1 {
                    folders[i].recipeIDs.removeAll { $0 == recipeID }
                }
            } }
        )
    }

    private func addWatchedFolder() {
        guard let recipe = recipes.first else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch"
        panel.message = "New images in this folder will be run through a recipe."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !watchedFolders.contains(where: { $0.path == url.path }) else { return }
        updateFolders { $0.append(WatchedFolder(path: url.path, recipeID: recipe.id)) }
    }

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

/// Triggers macOS's one-time folder prompts up front, so the first right-click
/// doesn't stall on a permission dialog.
enum FileAccess {
    static func requestCommonFolders() {
        let fm = FileManager.default
        let dirs: [FileManager.SearchPathDirectory] = [.desktopDirectory, .documentDirectory, .downloadsDirectory]
        for dir in dirs {
            guard let url = fm.urls(for: dir, in: .userDomainMask).first else { continue }
            // Listing the folder is what makes macOS show the prompt.
            _ = try? fm.contentsOfDirectory(atPath: url.path)
        }
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A small preview of a color theme: its canvas and surface with the accent
/// dot, drawn in the current light/dark appearance, and its name beneath.
private struct ThemeChip: View {
    let colorTheme: ColorTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { scheme == .dark ? colorTheme.dark : colorTheme.light }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: palette.canvas))
                    .frame(width: 54, height: 38)
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: palette.surfaceLowest))
                            .frame(width: 30, height: 18)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color(hex: palette.onSurface).opacity(0.7))
                                    .frame(width: 16, height: 3).padding(.leading, 5)
                            }
                            .padding(5)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(Color(hex: palette.accent)).frame(width: 12, height: 12).padding(5)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(isSelected ? Color.primary.opacity(0.75) : Color.primary.opacity(0.15),
                                          lineWidth: isSelected ? 2 : 1)
                    }
                Text(colorTheme.name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help(colorTheme.name)
    }
}
