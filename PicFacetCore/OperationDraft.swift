import Foundation

/// How the user wants to resize, before any typed value is parsed.
public enum ResizeMode: Hashable, Sendable, CaseIterable {
    case none
    case percent(Int)
    case customPercent
    case width
    case height
    case longEdge

    public static let presetPercents = [25, 50, 75]

    public static var allCases: [ResizeMode] {
        [.none] + presetPercents.map { .percent($0) } + [.customPercent, .width, .height, .longEdge]
    }

    public var title: String {
        switch self {
        case .none: return "No Change"
        case .percent(let percent): return "\(percent)%"
        case .customPercent: return "Custom %"
        case .width: return "Set width"
        case .height: return "Set height"
        case .longEdge: return "Fit long edge"
        }
    }

    public var systemImage: String? {
        switch self {
        case .none: return nil
        case .percent: return "arrow.down.right.and.arrow.up.left"
        case .customPercent: return "slider.horizontal.3"
        case .width: return "arrow.left.and.right"
        case .height: return "arrow.up.and.down"
        case .longEdge: return "arrow.up.left.and.arrow.down.right"
        }
    }

    /// Label and unit for the typed value this mode needs, or nil for none.
    public var entry: (label: String, suffix: String)? {
        switch self {
        case .none, .percent: return nil
        case .customPercent: return ("Custom scale", "%")
        case .width: return ("Target width", "px")
        case .height: return ("Target height", "px")
        case .longEdge: return ("Long edge", "px")
        }
    }
}

/// Target file size choice in the picker.
public enum TargetSizeChoice: Hashable, Sendable {
    case none
    case preset(Int)
    case custom

    /// Bytes.
    public static let presets = [200_000, 500_000, 1_000_000, 2_000_000, 5_000_000]

    public static var allCases: [TargetSizeChoice] { [.none] + presets.map { .preset($0) } + [.custom] }

    public var title: String {
        switch self {
        case .none: return "No Limit"
        case .preset(let bytes): return "Under \(formatBytes(bytes))"
        case .custom: return "Custom…"
        }
    }
}

/// Lossy quality presets shown in the picker, 1…100.
public enum QualityPreset {
    public static let all: [(title: String, value: Int)] = [
        ("Maximum (95)", 95), ("High (85)", 85), ("Web (75)", 75), ("Email (60)", 60), ("Small (40)", 40)
    ]
}

public enum WatermarkKind: String, CaseIterable, Sendable {
    case none, text, logo

    public var title: String {
        switch self {
        case .none: return "None"
        case .text: return "Text"
        case .logo: return "Logo image"
        }
    }
}

/// Everything the user has picked in an operation picker, including a
/// half-typed resize value. Turns into a `BatchSelection` once valid.
public struct OperationDraft: Equatable, Sendable {
    public var format: ImageFormat?
    public var resizeMode: ResizeMode
    public var dpi: Int?
    public var quality: Int?
    public var targetSize: TargetSizeChoice = .none
    public var metadata: MetadataMode?
    public var crop: CropRatio?
    public var watermarkKind: WatermarkKind = .none
    public var watermark = Watermark(text: "")
    public var renameTemplate = ""

    /// Typed values are kept per mode so switching modes does not lose them.
    private var entries: [ResizeMode: String] = [:]
    private var targetEntry = ""

    public static let maxEntryDigits = 5

    public init(format: ImageFormat? = nil, resizeMode: ResizeMode = .none, dpi: Int? = nil) {
        self.format = format
        self.resizeMode = resizeMode
        self.dpi = dpi
    }

    /// The draft that produces `selection`, e.g. when loading a recipe.
    public init(selection: BatchSelection) {
        self.init(format: selection.format, dpi: selection.dpi)
        switch selection.resize {
        case nil: resizeMode = .none
        case .percent(let p) where ResizeMode.presetPercents.contains(p): resizeMode = .percent(p)
        case .percent(let p): resizeMode = .customPercent; entryText = String(p)
        case .width(let w): resizeMode = .width; entryText = String(w)
        case .height(let h): resizeMode = .height; entryText = String(h)
        case .longEdge(let e): resizeMode = .longEdge; entryText = String(e)
        }
        quality = selection.quality
        if let bytes = selection.maxBytes {
            if TargetSizeChoice.presets.contains(bytes) {
                targetSize = .preset(bytes)
            } else {
                targetSize = .custom
                targetKBText = String(max(1, bytes / 1_000))
            }
        }
        metadata = selection.metadata
        crop = selection.crop
        if let mark = selection.watermark {
            watermark = mark
            watermarkKind = mark.logoPath != nil ? .logo : .text
        }
        renameTemplate = selection.rename?.template ?? ""
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
        case .longEdge: return positiveEntry.map { .longEdge($0) }
        }
    }

    /// False only when the mode needs a typed value and it is missing or zero.
    public var entryIsValid: Bool {
        resizeMode.entry == nil || positiveEntry != nil
    }

    /// Typed custom target size in KB. Setting it keeps digits only.
    public var targetKBText: String {
        get { targetEntry }
        set { targetEntry = String(newValue.filter(\.isNumber).prefix(Self.maxEntryDigits + 1)) }
    }

    public var maxBytes: Int? {
        switch targetSize {
        case .none: return nil
        case .preset(let bytes): return bytes
        case .custom:
            guard let kb = Int(targetEntry), kb > 0 else { return nil }
            return kb * 1_000
        }
    }

    public var targetIsValid: Bool { targetSize != .custom || maxBytes != nil }

    public var watermarkIsValid: Bool {
        switch watermarkKind {
        case .none: return true
        case .text: return !watermark.text.trimmingCharacters(in: .whitespaces).isEmpty
        case .logo: return watermark.logoPath != nil
        }
    }

    /// The watermark as configured for the current kind.
    private var activeWatermark: Watermark? {
        switch watermarkKind {
        case .none: return nil
        case .text:
            var mark = watermark
            mark.logoPath = nil
            return mark
        case .logo:
            return watermark.logoPath == nil ? nil : watermark
        }
    }

    private var built: BatchSelection {
        BatchSelection(
            format: format, resize: resize, dpi: dpi, quality: quality, maxBytes: maxBytes,
            metadata: metadata, crop: crop, watermark: activeWatermark,
            rename: renameTemplate.trimmingCharacters(in: .whitespaces).isEmpty ? nil : RenamePattern(renameTemplate)
        )
    }

    /// Why the draft can't run yet, or nil when every typed value is valid.
    private var problem: String? {
        if !entryIsValid { return "Enter a positive resize value to continue." }
        if !targetIsValid { return "Enter a target size in KB to continue." }
        if !watermarkIsValid {
            return watermarkKind == .text ? "Enter watermark text to continue." : "Choose a logo image to continue."
        }
        return nil
    }

    /// The runnable selection, or nil when nothing is picked or the entry is invalid.
    public var selection: BatchSelection? {
        guard problem == nil else { return nil }
        let selection = built
        return selection.hasSelection ? selection : nil
    }

    public var summary: String {
        if let problem { return problem }
        let selection = built
        return selection.hasSelection ? selection.summary : "Choose at least one operation to continue."
    }

    private var positiveEntry: Int? {
        guard let value = Int(entryText), value > 0 else { return nil }
        return value
    }
}
