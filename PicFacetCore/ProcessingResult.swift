import Foundation

public struct ProcessingResult {
    public let succeeded: [URL]
    public let failed: [(url: URL, error: Error)]

    public init(succeeded: [URL], failed: [(url: URL, error: Error)]) {
        self.succeeded = succeeded
        self.failed = failed
    }

    public var totalProcessed: Int { succeeded.count + failed.count }
    public var hasErrors: Bool { !failed.isEmpty }
}
