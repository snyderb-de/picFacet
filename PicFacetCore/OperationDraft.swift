import Foundation

/// How the user wants to resize, before any typed value is parsed.
public enum ResizeMode: Hashable, Sendable, CaseIterable {
    case none
    case percent(Int)
    case customPercent
    case width
    case height

    public static let presetPercents = [25, 50, 75]

    public static var allCases: [ResizeMode] {
        [.none] + presetPercents.map { .percent($0) } + [.customPercent, .width, .height]
    }

    public var title: String {
        switch self {
        case .none: return "No Change"
        case .percent(let percent): return "\(percent)%"
        case .customPercent: return "Custom %"
        case .width: return "Set width"
        case .height: return "Set height"
        }
    }

    public var systemImage: String? {
        switch self {
        case .none: return nil
        case .percent: return "arrow.down.right.and.arrow.up.left"
        case .customPercent: return "slider.horizontal.3"
        case .width: return "arrow.left.and.right"
        case .height: return "arrow.up.and.down"
        }
    }

    /// Label and unit for the typed value this mode needs, or nil for none.
    public var entry: (label: String, suffix: String)? {
        switch self {
        case .none, .percent: return nil
        case .customPercent: return ("Custom scale", "%")
        case .width: return ("Target width", "px")
        case .height: return ("Target height", "px")
        }
    }
}

/// Everything the user has picked in an operation picker, including a
/// half-typed resize value. Turns into a `BatchSelection` once valid.
public struct OperationDraft: Equatable, Sendable {
    public var format: ImageFormat?
    public var resizeMode: ResizeMode
    public var dpi: Int?

    /// Typed values are kept per mode so switching modes does not lose them.
    private var entries: [ResizeMode: String] = [:]

    public static let maxEntryDigits = 5

    public init(format: ImageFormat? = nil, resizeMode: ResizeMode = .none, dpi: Int? = nil) {
        self.format = format
        self.resizeMode = resizeMode
        self.dpi = dpi
    }

    /// Starting point from the user's saved defaults.
    public static func defaults(from settings: PicFacetSettings = .shared) -> OperationDraft {
        let resizeMode: ResizeMode = settings.defaultResizePercent.map {
            .percent(ResizeMode.presetPercents.contains($0) ? $0 : 50)
        } ?? .none
        return OperationDraft(
            format: settings.defaultFormat,
            resizeMode: resizeMode,
            dpi: settings.defaultDPI
        )
    }

    /// Typed value for the current resize mode. Setting it keeps digits only.
    public var entryText: String {
        get { entries[resizeMode] ?? "" }
        set { entries[resizeMode] = String(newValue.filter(\.isNumber).prefix(Self.maxEntryDigits)) }
    }

    public var resize: ResizeOperation? {
        switch resizeMode {
        case .none: return nil
        case .percent(let percent): return .percent(percent)
        case .customPercent: return positiveEntry.map { .percent($0) }
        case .width: return positiveEntry.map { .width($0) }
        case .height: return positiveEntry.map { .height($0) }
        }
    }

    /// False only when the mode needs a typed value and it is missing or zero.
    public var entryIsValid: Bool {
        resizeMode.entry == nil || positiveEntry != nil
    }

    /// The runnable selection, or nil when nothing is picked or the entry is invalid.
    public var selection: BatchSelection? {
        guard entryIsValid else { return nil }
        let selection = BatchSelection(format: format, resize: resize, dpi: dpi)
        return selection.hasSelection ? selection : nil
    }

    public var summary: String {
        guard entryIsValid else { return "Enter a positive resize value to continue." }
        let selection = BatchSelection(format: format, resize: resize, dpi: dpi)
        return selection.hasSelection ? selection.summary : "Choose at least one operation to continue."
    }

    private var positiveEntry: Int? {
        guard let value = Int(entryText), value > 0 else { return nil }
        return value
    }
}
