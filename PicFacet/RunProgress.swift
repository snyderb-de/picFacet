import Foundation

/// Every batch running in the app (Chooser, Batch window, Quick Actions,
/// Finder recipes, watched folders), summed for the menu bar indicator.
/// Runs in the PicFacet Watcher helper are a separate process and report by
/// notification instead.
@MainActor
final class RunProgress {
    static let shared = RunProgress()

    private var runs: [UUID: (completed: Int, total: Int)] = [:]

    /// Called after every change. The menu bar controller is the one observer.
    var onChange: (() -> Void)?

    var isRunning: Bool { !runs.isEmpty }
    var completed: Int { runs.values.reduce(0) { $0 + $1.completed } }
    var total: Int { runs.values.reduce(0) { $0 + $1.total } }

    var fraction: Double {
        let total = total
        return total > 0 ? Double(completed) / Double(total) : 0
    }

    /// "Processing 3 of 10 files…"
    var label: String {
        "Processing \(completed) of \(total) file\(total == 1 ? "" : "s")…"
    }

    func begin(total: Int) -> UUID {
        let id = UUID()
        runs[id] = (0, max(total, 1))
        onChange?()
        return id
    }

    func update(_ id: UUID, completed: Int, total: Int? = nil) {
        guard var run = runs[id] else { return }
        run.completed = completed
        if let total { run.total = max(total, 1) }
        runs[id] = run
        onChange?()
    }

    func end(_ id: UUID) {
        guard runs.removeValue(forKey: id) != nil else { return }
        onChange?()
    }
}
