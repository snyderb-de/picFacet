import Foundation

public final class PicFacetSettings {
    public static let shared = PicFacetSettings()

    public enum AppAppearance: String, CaseIterable {
        case system
        case light
        case dark
    }

    // Uses App Group container so both the main app and extension share the same defaults.
    // Falls back to .standard during development before provisioning is configured.
    private let defaults: UserDefaults

    private static let appGroupID = "group.com.picfacet.shared"

    private init() {
        defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
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
    
    public var defaultFormat: ImageFormat {
        get {
            guard let rawValue = defaults.string(forKey: Keys.defaultFormat),
                  let format = ImageFormat(rawValue: rawValue) else {
                return .jpeg
            }
            return format
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.defaultFormat) }
    }
    
    public var defaultResizePercent: Int {
        get { defaults.object(forKey: Keys.defaultResizePercent) as? Int ?? 50 }
        set { defaults.set(newValue, forKey: Keys.defaultResizePercent) }
    }
    
    public var defaultDPI: Int {
        get { defaults.object(forKey: Keys.defaultDPI) as? Int ?? 72 }
        set { defaults.set(newValue, forKey: Keys.defaultDPI) }
    }

    // MARK: - Constants

    public static let dpiOptions: [Int] = [72, 96, 150, 300, 600, 1200, 2400, 3600]

    // MARK: - Keys

    private enum Keys {
        static let overwriteSource           = "overwriteSource"
        static let onlyIfSmaller             = "onlyIfSmaller"
        static let deleteOriginalAfterConvert = "deleteOriginalAfterConvert"
        static let isProportional            = "isProportional"
        static let resizePresets             = "resizePresets"
        static let customOutputFolder        = "customOutputFolder"
        static let appAppearance             = "appAppearance"
        static let defaultFormat             = "defaultFormat"
        static let defaultResizePercent      = "defaultResizePercent"
        static let defaultDPI                = "defaultDPI"
    }
}
