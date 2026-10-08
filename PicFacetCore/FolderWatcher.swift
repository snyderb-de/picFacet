import Foundation
@preconcurrency import UserNotifications

/// Watches each enabled folder in Settings and hands images that appear there
/// to `run` with the folder's recipe. Used by the app, and by the PicFacet
/// Watcher login item when watching continues in the background.
///
/// Only the folder itself is watched (not subfolders), and results go to its
/// "Processed" subfolder, so outputs never retrigger. Each folder's file list
/// is saved, so files added while nothing was watching are picked up on the
/// next start. A folder with no saved list (just added or re-enabled) starts
/// from what is there now: existing files are left alone.
@MainActor
public final class FolderWatcher {
    public typealias Runner = @MainActor (_ urls: [URL], _ recipes: [Recipe], _ folder: WatchedFolder) -> Void

    private final class Watch {
        let folder: WatchedFolder
        let source: DispatchSourceFileSystemObject
        var known: Set<String>
        var pending: Task<Void, Never>?

        init(folder: WatchedFolder, source: DispatchSourceFileSystemObject, known: Set<String>) {
            self.folder = folder
            self.source = source
            self.known = known
        }
    }

    private let settings: PicFacetSettings
    private let run: Runner
    private var watches: [UUID: Watch] = [:]

    /// How long the folder must be quiet before new files are checked.
    private static let settleDelay: Duration = .seconds(1.5)

    public init(settings: PicFacetSettings = .shared, run: @escaping Runner) {
        self.settings = settings
        self.run = run
    }

    public var watchedCount: Int { watches.count }

    /// Starts, stops or restarts watches to match Settings.
    public func reload() {
        let wanted = settings.watchedFolders.filter(\.isEnabled)
        for (id, watch) in watches where !wanted.contains(watch.folder) {
            stop(id, watch)
        }
        for folder in wanted where watches[folder.id] == nil {
            start(folder)
        }
    }

    public func stopAll() {
        for (id, watch) in watches { stop(id, watch) }
    }

    private func stop(_ id: UUID, _ watch: Watch) {
        watch.pending?.cancel()
        watch.source.cancel()
        watches[id] = nil
    }

    private func start(_ folder: WatchedFolder) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[PicFacet] can't watch %@", folder.path)
            return
        }
        let current = Set(Self.contents(of: folder.url).map(\.lastPathComponent))
        let known: Set<String>
        if let saved = settings.watchSnapshot(for: folder.id) {
            known = saved
        } else {
            known = current
            settings.setWatchSnapshot(current, for: folder.id)
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        let watch = Watch(folder: folder, source: source, known: known)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.changed(folder.id) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watches[folder.id] = watch
        NSLog("[PicFacet] watching %@", folder.path)

        // Catch up on anything added while nothing was watching.
        if !current.subtracting(known).isEmpty { changed(folder.id) }
    }

    private func changed(_ id: UUID) {
        guard let watch = watches[id] else { return }
        watch.pending?.cancel()
        watch.pending = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            await self?.processNewFiles(id)
        }
    }

    private func processNewFiles(_ id: UUID) async {
        guard let watch = watches[id] else { return }
        let folder = watch.folder
        let current = Self.contents(of: folder.url)
        let knownPaths = Set(watch.known.map { folder.url.appendingPathComponent($0).path })
        let candidates = WatchedFolder.newFiles(in: current, known: knownPaths)
        var ready: [URL] = []
        for url in candidates where await Self.isSettled(url) {
            ready.append(url)
        }
        // Files still being written stay unknown and are checked again shortly;
        // removed files are forgotten so a re-added one counts as new.
        let unsettled = Set(candidates.map(\.lastPathComponent)).subtracting(ready.map(\.lastPathComponent))
        watch.known = Set(current.map(\.lastPathComponent)).subtracting(unsettled)
        settings.setWatchSnapshot(watch.known, for: id)
        if !unsettled.isEmpty { changed(id) }
        guard !ready.isEmpty else { return }

        let recipes = folder.recipeIDs.compactMap(settings.recipe(id:))
        guard !recipes.isEmpty else {
            NSLog("[PicFacet] watched folder %@ has no recipe", folder.path)
            return
        }
        NSLog("[PicFacet] watched folder: %d new file(s) × %d recipe(s) in %@", ready.count, recipes.count, folder.path)
        run(ready, recipes, folder)
    }

    nonisolated private static func contents(of folder: URL) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        return urls.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
    }

    /// True once the file's size is non-zero and unchanged across a short wait,
    /// so a copy or download in progress isn't read half-written.
    nonisolated private static func isSettled(_ url: URL) async -> Bool {
        let first = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        try? await Task.sleep(for: .milliseconds(500))
        let second = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return first > 0 && first == second
    }
}

/// Cross-process signals between the app and the PicFacet Watcher login item.
public enum WatcherSignal {
    /// Posted by the app when watched folders, recipes or the background option change.
    public static let settingsChanged = Notification.Name("com.picfacet.watcher.settingsChanged")

    public static func postSettingsChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            settingsChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

public extension WatchedFolder {
    /// "Blog + Print · Inbox"
    func runTitle(_ recipes: [Recipe]) -> String {
        "\(recipes.map(\.name).joined(separator: " + ")) · \(url.lastPathComponent)"
    }
}

/// Banner after background runs (Quick Actions, Finder recipes, watched folders).
public enum RunNotifier {
    public static func post(title: String, body: String, settings: PicFacetSettings = .shared) {
        guard settings.notifyAfterRuns else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    /// "2 files saved. Saved 4.2 MB (68%) …", plus failures and kept originals.
    public static func body(for result: ProcessingResult) -> String {
        var parts: [String] = []
        let saved = result.succeeded.count
        if saved > 0 { parts.append("\(saved) file\(saved == 1 ? "" : "s") saved.") }
        if let savings = result.savingsText { parts.append(savings) }
        let kept = result.keptOriginal.count
        if kept > 0 { parts.append("\(kept) kept unchanged (result wasn't smaller).") }
        if let failure = result.failed.first {
            parts.append("\(result.failed.count) failed: \(failure.url.lastPathComponent): \(failure.error.localizedDescription)")
        }
        return parts.joined(separator: " ")
    }
}
