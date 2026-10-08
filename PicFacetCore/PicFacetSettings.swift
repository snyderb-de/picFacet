import Foundation

// UserDefaults is thread-safe; the only stored property is an immutable reference to it.
public final class PicFacetSettings: @unchecked Sendable {
    public static let shared = PicFacetSettings()

    public enum AppAppearance: String, CaseIterable, Sendable {
        case system
        case light
        case dark
    }

    // Uses the App Group container so the app, the Finder extension and the
    // background watcher share the same defaults.
    private let defaults: UserDefaults

    /// "<TeamID>.com.picfacet.shared", from the `PicFacetAppGroup` Info.plist key.
    public static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "PicFacetAppGroup") as? String ?? legacyAppGroupID
    }

    /// Group used up to 1.2.3. Its ID isn't team-prefixed, so only App IDs
    /// registered for it (the main app) may open it.
    static let legacyAppGroupID = "group.com.picfacet.shared"

    private convenience init() {
        self.init(defaults: UserDefaults(suiteName: Self.appGroupID) ?? .standard)
    }

    /// Settings backed by any defaults store. Tests pass a scratch suite.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Copies settings from the legacy group once. Main app only: other
    /// targets can't read the legacy group and would mark it done with nothing copied.
    public func migrateLegacyAppGroupIfNeeded() {
        guard Self.appGroupID != Self.legacyAppGroupID,
              let legacy = UserDefaults(suiteName: Self.legacyAppGroupID) else { return }
        migrate(from: legacy)
    }

    /// Copies PicFacet's own keys that aren't set here yet. Read through the
    /// suite (not `persistentDomain`), so an entitled app gets the group
    /// container's values rather than a stray plist in ~/Library/Preferences.
    func migrate(from legacy: UserDefaults) {
        guard !defaults.bool(forKey: Keys.migratedLegacyGroup) else { return }
        var copied = 0
        for key in Keys.all where defaults.object(forKey: key) == nil {
            guard let value = legacy.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
            copied += 1
        }
        defaults.set(true, forKey: Keys.migratedLegacyGroup)
        NSLog("[PicFacet] migrated %ld setting(s) from the previous settings group", copied)
    }

    // MARK: - General

    public var overwriteSource: Bool {
        get { defaults.bool(forKey: Keys.overwriteSource) }
        set { defaults.set(newValue, forKey: Keys.overwriteSource) }
    }

    public var onlyIfSmaller: Bool {
        get { defaults.bool(forKey: Keys.onlyIfSmaller) }
        set { defaults.set(newValue, forKey: Keys.onlyIfSmaller) }
    }

    public var deleteOriginalAfterConvert: Bool {
        get { defaults.bool(forKey: Keys.deleteOriginalAfterConvert) }
        set { defaults.set(newValue, forKey: Keys.deleteOriginalAfterConvert) }
    }

    /// Off by default: resizing or re-tagging a format PicFacet can't write
    /// (RAW, ICO, PSD…) is refused instead of silently producing a JPEG.
    public var saveUnsupportedAsJPEG: Bool {
        get { defaults.bool(forKey: Keys.saveUnsupportedAsJPEG) }
        set { defaults.set(newValue, forKey: Keys.saveUnsupportedAsJPEG) }
    }

    // MARK: - Resize

    public var isProportional: Bool {
        get { defaults.object(forKey: Keys.isProportional) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.isProportional) }
    }

    /// Preset labels shown in the right-click Resize submenu, e.g. ["25%", "50%", "75%"]
    public var resizePresets: [String] {
        get { defaults.stringArray(forKey: Keys.resizePresets) ?? ["25%", "50%", "75%"] }
        set { defaults.set(newValue, forKey: Keys.resizePresets) }
    }

    // MARK: - Output

    /// nil = same folder as source
    public var customOutputFolder: String? {
        get { defaults.string(forKey: Keys.customOutputFolder) }
        set { defaults.set(newValue, forKey: Keys.customOutputFolder) }
    }

    /// Snapshot of the output rules for one batch.
    public var outputPolicy: OutputPolicy {
        OutputPolicy(
            overwriteSource: overwriteSource,
            onlyIfSmaller: onlyIfSmaller,
            deleteOriginalAfterConvert: deleteOriginalAfterConvert,
            isProportional: isProportional,
            saveUnsupportedAsJPEG: saveUnsupportedAsJPEG,
            customOutputFolder: customOutputFolder.map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
    }

    // MARK: - Appearance

    public var appAppearance: AppAppearance {
        get {
            guard let rawValue = defaults.string(forKey: Keys.appAppearance),
                  let appearance = AppAppearance(rawValue: rawValue) else {
                return .system  // Default to system
            }
            return appearance
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.appAppearance) }
    }
    
    // MARK: - Defaults
    
    // nil means "No Change". It is stored as a sentinel ("none" / 0) so that
    // it differs from a missing key, which falls back to the shipped default.

    public var defaultFormat: ImageFormat? {
        get {
            guard let rawValue = defaults.string(forKey: Keys.defaultFormat) else { return .jpeg }
            return ImageFormat(rawValue: rawValue)
        }
        set { defaults.set(newValue?.rawValue ?? Self.noChange, forKey: Keys.defaultFormat) }
    }

    public var defaultResizePercent: Int? {
        get { positive(Keys.defaultResizePercent, fallback: 50) }
        set { defaults.set(newValue ?? 0, forKey: Keys.defaultResizePercent) }
    }

    public var defaultDPI: Int? {
        get { positive(Keys.defaultDPI, fallback: 72) }
        set { defaults.set(newValue ?? 0, forKey: Keys.defaultDPI) }
    }

    private static let noChange = "none"

    private func positive(_ key: String, fallback: Int) -> Int? {
        guard let value = defaults.object(forKey: key) as? Int else { return fallback }
        return value > 0 ? value : nil
    }

    // MARK: - Theme

    /// Color theme id ("default", "dracula", …); the app maps it to a palette.
    public var colorTheme: String {
        get { defaults.string(forKey: Keys.colorTheme) ?? "default" }
        set { defaults.set(newValue, forKey: Keys.colorTheme) }
    }

    /// Accent colour: a preset name ("blue", "system", …) or "#RRGGBB".
    public var accentColor: String {
        get { defaults.string(forKey: Keys.accentColor) ?? "blue" }
        set { defaults.set(newValue, forKey: Keys.accentColor) }
    }

    /// Window background: a preset name ("accent", "none", …) or "#RRGGBB,#RRGGBB".
    public var backdrop: String {
        get { defaults.string(forKey: Keys.backdrop) ?? "accent" }
        set { defaults.set(newValue, forKey: Keys.backdrop) }
    }

    // MARK: - Recipes

    public var recipes: [Recipe] {
        get { decoded([Recipe].self, Keys.recipes) ?? [] }
        set { encode(newValue, Keys.recipes) }
    }

    public func recipe(id: UUID) -> Recipe? {
        recipes.first { $0.id == id }
    }

    public var watchedFolders: [WatchedFolder] {
        get { decoded([WatchedFolder].self, Keys.watchedFolders) ?? [] }
        set { encode(newValue, Keys.watchedFolders) }
    }

    /// Keep watching folders when the app isn't running, via the PicFacet
    /// Watcher login item. The app registers the login item; this records the choice.
    public var watchInBackground: Bool {
        get { defaults.bool(forKey: Keys.watchInBackground) }
        set { defaults.set(newValue, forKey: Keys.watchInBackground) }
    }

    /// File names last seen in a watched folder, or nil if it has never been
    /// scanned. Lets a watcher catch up on files added while it wasn't running.
    public func watchSnapshot(for id: UUID) -> Set<String>? {
        let all = defaults.dictionary(forKey: Keys.watchSnapshots) as? [String: [String]]
        return all?[id.uuidString].map(Set.init)
    }

    /// nil forgets the folder's list, so the next start ignores existing files.
    public func setWatchSnapshot(_ names: Set<String>?, for id: UUID) {
        var all = defaults.dictionary(forKey: Keys.watchSnapshots) as? [String: [String]] ?? [:]
        all[id.uuidString] = names.map { $0.sorted() }
        defaults.set(all, forKey: Keys.watchSnapshots)
    }

    /// Show a notification with the size saved after a Quick Action or watched-folder run.
    public var notifyAfterRuns: Bool {
        get { defaults.object(forKey: Keys.notifyAfterRuns) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.notifyAfterRuns) }
    }

    /// Shared secret the Finder extension puts in `picfacet://run` links, so a
    /// web page or other app can't run a recipe on the user's files.
    /// Created on first use.
    public var recipeRunToken: String {
        if let token = defaults.string(forKey: Keys.recipeRunToken), token.count >= 32 { return token }
        let token = UUID().uuidString + UUID().uuidString
        defaults.set(token, forKey: Keys.recipeRunToken)
        return token
    }

    private func decoded<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    // MARK: - Constants

    public static let dpiOptions: [Int] = [72, 96, 150, 300, 600, 1200, 2400, 3600]

    // MARK: - Keys

    private enum Keys {
        static let overwriteSource           = "overwriteSource"
        static let onlyIfSmaller             = "onlyIfSmaller"
        static let deleteOriginalAfterConvert = "deleteOriginalAfterConvert"
        static let saveUnsupportedAsJPEG     = "saveUnsupportedAsJPEG"
        static let isProportional            = "isProportional"
        static let resizePresets             = "resizePresets"
        static let customOutputFolder        = "customOutputFolder"
        static let appAppearance             = "appAppearance"
        static let defaultFormat             = "defaultFormat"
        static let defaultResizePercent      = "defaultResizePercent"
        static let defaultDPI                = "defaultDPI"
        static let colorTheme                = "colorTheme"
        static let accentColor               = "accentColor"
        static let backdrop                  = "backdrop"
        static let recipes                   = "recipes"
        static let watchedFolders            = "watchedFolders"
        static let notifyAfterRuns           = "notifyAfterRuns"
        static let recipeRunToken            = "recipeRunToken"
        static let watchInBackground         = "watchInBackground"
        static let watchSnapshots            = "watchSnapshots"
        static let migratedLegacyGroup       = "migratedLegacyGroup"

        /// Everything carried over from the legacy group.
        static let all = [
            overwriteSource, onlyIfSmaller, deleteOriginalAfterConvert, saveUnsupportedAsJPEG, isProportional,
            resizePresets, customOutputFolder, appAppearance, defaultFormat, defaultResizePercent, defaultDPI,
            colorTheme, accentColor, backdrop, recipes, watchedFolders, notifyAfterRuns, recipeRunToken,
            watchInBackground, watchSnapshots
        ]
    }
}
