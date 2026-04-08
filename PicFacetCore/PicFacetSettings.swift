import Foundation

public final class PicFacetSettings {
    public static let shared = PicFacetSettings()

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
    }
}
