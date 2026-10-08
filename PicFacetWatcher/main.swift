import AppKit
import PicFacetCore

// PicFacet Watcher: a background-only login item that keeps watched folders
// running when PicFacet itself is closed. PicFacet registers it (Settings →
// Watched Folders → "Keep watching when PicFacet is closed") and it starts at
// login. It has no UI; results are reported as notifications.

@MainActor
final class WatcherDelegate: NSObject, NSApplicationDelegate {
    private let settings = PicFacetSettings.shared

    private var watcher: FolderWatcher!

    private func makeWatcher() -> FolderWatcher {
        let settings = self.settings
        return FolderWatcher(settings: settings, run: { urls, recipes, folder in
            Task {
                let result = await folder.process(urls, recipes: recipes, base: settings.outputPolicy) { _, _ in }
                NSLog("[PicFacetWatcher] %@: ok=%d kept=%d failed=%d", folder.path,
                      result.succeeded.count, result.keptOriginal.count, result.failed.count)
                RunNotifier.post(title: folder.runTitle(recipes), body: RunNotifier.body(for: result), settings: settings)
            }
        })
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        watcher = makeWatcher()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(settingsChanged), name: WatcherSignal.settingsChanged, object: nil)
        settingsChanged()
    }

    @objc private func settingsChanged() {
        guard settings.watchInBackground else {
            NSLog("[PicFacetWatcher] background watching is off; quitting")
            watcher.stopAll()
            NSApp.terminate(nil)
            return
        }
        watcher.reload()
        NSLog("[PicFacetWatcher] watching %d folder(s)", watcher.watchedCount)
    }
}

let app = NSApplication.shared
let delegate = WatcherDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)
app.run()
