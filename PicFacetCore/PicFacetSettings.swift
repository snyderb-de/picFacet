import Foundation

// UserDefaults is thread-safe; the only stored property is an immutable reference to it.
public final class PicFacetSettings: @unchecked Sendable {
    public static let shared = PicFacetSettings()

    public enum AppAppearance: String, CaseIterable, Sendable {
        case system
        case light
        case dark
    }

    // Uses App Group container so both the main app and extension share the same defaults.
    // Falls back to .standard during development before provisioning is configured.
    private let defaults: UserDefaults

    private static let appGroupID = "group.com.picfacet.shared"

    private convenience init() {
        self.init(defaults: UserDefaults(suiteName: Self.appGroupID) ?? .standard)
    }

    /// Settings backed by any defaults store. Tests pass a scratch suite.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
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
    /// (RAW, AVIF, ICO…) is refused instead of silently producing a JPEG.
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
    }
}
