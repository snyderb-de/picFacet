import Foundation

/// What happened to one file of a batch.
public struct FileReport: Sendable {
    public enum Outcome: Sendable {
        /// The result was saved here (the source itself when overwriting).
        case written(URL)
        /// The source was left untouched: "Keep result only if smaller" discarded
        /// the result, or there was nothing to change.
        case keptOriginal
        case failed(any Error)
    }

    public let source: URL
    public let outcome: Outcome
    /// Size of the source before processing, when known.
    public let originalBytes: Int?
    /// Size of the encoded result, including a discarded one.
    public let resultBytes: Int?

    public init(source: URL, outcome: Outcome, originalBytes: Int? = nil, resultBytes: Int? = nil) {
        self.source = source
        self.outcome = outcome
        self.originalBytes = originalBytes
        self.resultBytes = resultBytes
    }
}

/// Progress after each finished file.
public struct BatchProgress: Sendable {
    public let completed: Int
    public let total: Int
    public let latest: FileReport
}

public struct ProcessingResult: Sendable {
    /// One report per input file, in completion order.
    public let reports: [FileReport]

    public init(reports: [FileReport]) {
        self.reports = reports
    }

    /// Output files that were written.
    public var succeeded: [URL] {
        reports.compactMap { if case .written(let url) = $0.outcome { url } else { nil } }
    }

    /// Sources left as they were because the result was not smaller.
    public var keptOriginal: [URL] {
        reports.compactMap { if case .keptOriginal = $0.outcome { $0.source } else { nil } }
    }

    public var failed: [(url: URL, error: any Error)] {
        reports.compactMap { if case .failed(let error) = $0.outcome { ($0.source, error) } else { nil } }
    }

    public var totalProcessed: Int { reports.count }
    public var hasErrors: Bool { !failed.isEmpty }
}
