import Foundation

/// A named, saved `BatchSelection`, e.g. "Blog: long edge 1600 → WebP q80 → strip GPS".
/// Shown in the Chooser, the Batch window, Finder's PicFacet menu and Shortcuts.
public struct Recipe: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var selection: BatchSelection

    public init(id: UUID = UUID(), name: String, selection: BatchSelection) {
        self.id = id
        self.name = name
        self.selection = selection
    }
}

/// A folder whose new images are run through one or more recipes automatically.
/// Each recipe makes its own output from the original image.
public struct WatchedFolder: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var path: String
    /// Run in this order, each on the original file.
    public var recipeIDs: [UUID]
    public var isEnabled: Bool
    /// Permanently delete (not to the Trash) each dropped file once every
    /// recipe has saved its result. Off unless the user confirms it.
    public var deleteOriginals: Bool

    public init(id: UUID = UUID(), path: String, recipeIDs: [UUID], isEnabled: Bool = true, deleteOriginals: Bool = false) {
        self.id = id
        self.path = path
        self.recipeIDs = recipeIDs
        self.isEnabled = isEnabled
        self.deleteOriginals = deleteOriginals
    }

    public init(id: UUID = UUID(), path: String, recipeID: UUID, isEnabled: Bool = true, deleteOriginals: Bool = false) {
        self.init(id: id, path: path, recipeIDs: [recipeID], isEnabled: isEnabled, deleteOriginals: deleteOriginals)
    }

    private enum CodingKeys: String, CodingKey { case id, path, recipeIDs, recipeID, isEnabled, deleteOriginals }

    /// Folders saved by earlier builds have a single `recipeID` and no `deleteOriginals`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        path = try c.decode(String.self, forKey: .path)
        if let ids = try c.decodeIfPresent([UUID].self, forKey: .recipeIDs) {
            recipeIDs = ids
        } else {
            recipeIDs = [try c.decode(UUID.self, forKey: .recipeID)]
        }
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        deleteOriginals = try c.decodeIfPresent(Bool.self, forKey: .deleteOriginals) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(path, forKey: .path)
        try c.encode(recipeIDs, forKey: .recipeIDs)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(deleteOriginals, forKey: .deleteOriginals)
    }

    public static let outputFolderName = "Processed"

    public var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    /// Results go in a subfolder. The watch is not recursive, so outputs never
    /// trigger another run.
    public var outputURL: URL { url.appendingPathComponent(Self.outputFolderName, isDirectory: true) }

    /// With one recipe, "Processed/"; with several, "Processed/<recipe name>/"
    /// so their outputs can't collide.
    public func outputURL(for recipe: Recipe) -> URL {
        guard recipeIDs.count > 1 else { return outputURL }
        var name = recipe.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        while name.hasPrefix(".") { name.removeFirst() }
        return outputURL.appendingPathComponent(name.isEmpty ? recipe.id.uuidString : name, isDirectory: true)
    }

    /// Watched runs never overwrite or delete what was dropped in, whatever
    /// the global settings say: the user didn't pick these files by hand.
    /// Deleting originals is handled by `process`, after every recipe.
    public func policy(from base: OutputPolicy, recipe: Recipe) -> OutputPolicy {
        var policy = base
        policy.overwriteSource = false
        policy.deleteOriginalAfterConvert = false
        policy.deleteSourceAfterWrite = false
        policy.saveUnsupportedAsJPEG = true
        policy.customOutputFolder = outputURL(for: recipe)
        return policy
    }

    /// Runs every recipe on `urls`, each from the original, then permanently
    /// deletes the originals that every recipe wrote (when `deleteOriginals` is on).
    /// Returns all reports together.
    /// `onProgress` gets (completed, total) over every file × recipe.
    public func process(
        _ urls: [URL], recipes: [Recipe], base: OutputPolicy,
        onProgress: @escaping @MainActor @Sendable (Int, Int) -> Void = { _, _ in }
    ) async -> ProcessingResult {
        var reports: [FileReport] = []
        var writtenBy: [String: Int] = [:]
        let total = urls.count * recipes.count
        for (step, recipe) in recipes.enumerated() {
            let offset = step * urls.count
            let policy = policy(from: base, recipe: recipe)
            if let folder = policy.customOutputFolder {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let result = await ImageProcessor.process(urls, recipe.selection, policy: policy) { p in
                onProgress(offset + p.completed, total)
            }
            for report in result.reports {
                if case .written = report.outcome { writtenBy[report.source.path, default: 0] += 1 }
            }
            reports += result.reports
        }
        if deleteOriginals && !recipes.isEmpty {
            for url in urls where writtenBy[url.path] == recipes.count {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return ProcessingResult(reports: reports)
    }

    /// Files in `current` that weren't in `known` and look like finished,
    /// processable images (no hidden or staging files).
    public static func newFiles(in current: [URL], known: Set<String>) -> [URL] {
        current.filter { url in
            !known.contains(url.path)
                && !url.lastPathComponent.hasPrefix(".")
                && url.isProcessableFile
        }
    }
}
