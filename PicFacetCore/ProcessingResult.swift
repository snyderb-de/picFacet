import Foundation

public struct ProcessingResult {
    public let succeeded: [URL]
    public let failed: [(url: URL, error: Error)]

    public var totalProcessed: Int { succeeded.count + failed.count }
    public var hasErrors: Bool { !failed.isEmpty }
}
