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
    /// Further files written for this source: pages 2… of a PDF.
    public let extraOutputs: [URL]
    /// Something the user should know about a written file, e.g. a missed size target.
    public let note: String?

    public init(source: URL, outcome: Outcome, originalBytes: Int? = nil, resultBytes: Int? = nil,
                extraOutputs: [URL] = [], note: String? = nil) {
        self.source = source
        self.outcome = outcome
        self.originalBytes = originalBytes
        self.resultBytes = resultBytes
        self.extraOutputs = extraOutputs
        self.note = note
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

    /// Output files that were written, every PDF page included.
    public var succeeded: [URL] {
        reports.flatMap { report -> [URL] in
            if case .written(let url) = report.outcome { [url] + report.extraOutputs } else { [] }
        }
    }

    /// Bytes before and after, over the files that were written.
    public var bytesBefore: Int {
        reports.reduce(0) { if case .written = $1.outcome { $0 + ($1.originalBytes ?? 0) } else { $0 } }
    }

    public var bytesAfter: Int {
        reports.reduce(0) { if case .written = $1.outcome { $0 + ($1.resultBytes ?? 0) } else { $0 } }
    }

    /// "Saved 4.2 MB (68%)", "Grew by 120 KB (+12%)", or nil when nothing was written.
    public var savingsText: String? {
        let before = bytesBefore, after = bytesAfter
        guard before > 0, after > 0 else { return nil }
        let percent = Int((Double(abs(before - after)) / Double(before) * 100).rounded())
        if after <= before {
            return "Saved \(formatBytes(before - after)) (\(percent)%) · \(formatBytes(before)) → \(formatBytes(after))"
        }
        return "Grew by \(formatBytes(after - before)) (+\(percent)%) · \(formatBytes(before)) → \(formatBytes(after))"
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
