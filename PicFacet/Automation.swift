import AppKit
import ServiceManagement
import PicFacetCore

extension Notification.Name {
    static let picFacetRecipesChanged = Notification.Name("picfacet.recipesChanged")
}

// MARK: - Recipes

/// Saves and removes recipes, and tells open windows to refresh their lists.
enum RecipeStore {
    static var all: [Recipe] { PicFacetSettings.shared.recipes }

    static func add(_ recipe: Recipe) {
        PicFacetSettings.shared.recipes.append(recipe)
        changed()
    }

    static func update(_ recipe: Recipe) {
        var recipes = all
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index] = recipe
        PicFacetSettings.shared.recipes = recipes
        changed()
    }

    static func delete(_ id: UUID) {
        PicFacetSettings.shared.recipes.removeAll { $0.id == id }
        // Take the recipe out of watched folders; a folder left with none would do nothing.
        var folders = PicFacetSettings.shared.watchedFolders
        for i in folders.indices { folders[i].recipeIDs.removeAll { $0 == id } }
        PicFacetSettings.shared.watchedFolders = folders.filter { !$0.recipeIDs.isEmpty }
        changed()
    }

    /// Asks for a name and saves `selection` as a new recipe.
    @discardableResult
    static func promptToSave(_ selection: BatchSelection) -> Recipe? {
        let alert = NSAlert()
        alert.messageText = "Save Recipe"
        alert.informativeText = selection.summary
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "Recipe name, e.g. Blog photos"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        let recipe = Recipe(name: name.isEmpty ? selection.summary : name, selection: selection)
        add(recipe)
        return recipe
    }

    private static func changed() {
        NotificationCenter.default.post(name: .picFacetRecipesChanged, object: nil)
    }
}

// MARK: - Background runs

/// Runs a selection with no window open: Finder Quick Actions, Finder recipe
/// items and watched folders. Success is a notification; anything the user
/// would otherwise miss (kept originals, failures) is an alert.
enum QuickRun {
    static func run(_ urls: [URL], _ selection: BatchSelection, policy: OutputPolicy, title: String) {
        guard !urls.isEmpty else { return }
        let tracked = RunProgress.shared.begin(total: urls.count)
        Task {
            let result = await ImageProcessor.process(urls, selection, policy: policy) { p in
                RunProgress.shared.update(tracked, completed: p.completed)
            }
            RunProgress.shared.end(tracked)
            report(result, summary: selection.summary, title: title)
        }
    }

    static func report(_ result: ProcessingResult, summary: String, title: String) {
        NSLog("[PicFacet] done — ok=%d kept=%d failed=%d",
              result.succeeded.count, result.keptOriginal.count, result.failed.count)
        for f in result.failed {
            NSLog("[PicFacet] fail %@: %@", f.url.lastPathComponent, f.error.localizedDescription)
        }
        if !result.keptOriginal.isEmpty || result.hasErrors {
            CompletionAlert.show(result, summary: summary)
        } else {
            RunNotifier.post(title: title, body: RunNotifier.body(for: result))
        }
    }
}

// MARK: - Watched folders

/// Runs the folder watcher in the app, unless the PicFacet Watcher login item
/// is doing it in the background.
@MainActor
final class FolderWatchController {
    static let shared = FolderWatchController()

    private let watcher: FolderWatcher

    private init() {
        watcher = FolderWatcher(settings: .shared, run: Self.run)
    }

    private static func run(_ urls: [URL], _ recipes: [Recipe], _ folder: WatchedFolder) {
        let tracked = RunProgress.shared.begin(total: urls.count * recipes.count)
        Task {
            let result = await folder.process(urls, recipes: recipes, base: PicFacetSettings.shared.outputPolicy) { done, total in
                RunProgress.shared.update(tracked, completed: done, total: total)
            }
            RunProgress.shared.end(tracked)
            QuickRun.report(result, summary: recipes.map(\.name).joined(separator: " + "), title: folder.runTitle(recipes))
        }
    }

    /// Matches watches to Settings, and tells the login item to do the same.
    func reload() {
        NSLog("[PicFacet] watch reload: background option %@, login item status %ld",
              PicFacetSettings.shared.watchInBackground ? "on" : "off", BackgroundWatching.status.rawValue)
        if BackgroundWatching.isActive {
            watcher.stopAll()
            BackgroundWatching.ensureHelperRunning()
        } else {
            watcher.reload()
        }
        WatcherSignal.postSettingsChanged()
    }

    /// For a folder the user just added or switched back on: start from what
    /// is in it now instead of processing everything added since.
    func resetHistory(_ id: UUID) {
        PicFacetSettings.shared.setWatchSnapshot(nil, for: id)
    }
}

/// The PicFacet Watcher login item, which keeps watched folders running when
/// PicFacet is closed and starts at login.
@MainActor
enum BackgroundWatching {
    static let helperBundleID = "com.picfacet.app.watcher"
    private static var service: SMAppService { SMAppService.loginItem(identifier: helperBundleID) }

    static var status: SMAppService.Status { service.status }

    /// True when the login item is registered and allowed to run, so the app
    /// leaves watching to it.
    static var isActive: Bool {
        PicFacetSettings.shared.watchInBackground && status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            // Set first: register() launches the helper at once, and it quits
            // if it reads the option as off.
            PicFacetSettings.shared.watchInBackground = true
            do {
                try service.register()
            } catch {
                PicFacetSettings.shared.watchInBackground = false
                throw error
            }
        } else {
            PicFacetSettings.shared.watchInBackground = false
            // The helper quits when it sees the option is off.
            WatcherSignal.postSettingsChanged()
            try? service.unregister()
        }
        FolderWatchController.shared.reload()
    }

    /// Re-registers at launch if the option is on but the item was lost
    /// (e.g. the app was moved).
    static func restoreIfNeeded() {
        guard PicFacetSettings.shared.watchInBackground, status == .notRegistered else { return }
        do { try service.register() } catch {
            NSLog("[PicFacet] couldn't re-register background watcher: %@", error.localizedDescription)
        }
    }

    /// Starts the helper if it is registered but not running, e.g. after it
    /// crashed or was quit. launchd only starts login items at login.
    static func ensureHelperRunning() {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: helperBundleID).isEmpty else { return }
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/PicFacetWatcher.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: helper, configuration: config) { _, error in
            if let error { NSLog("[PicFacet] couldn't start background watcher: %@", error.localizedDescription) }
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
