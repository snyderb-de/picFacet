import Foundation

public enum PicFacetError: Error, LocalizedError {
    case unreadableFile(URL)
    case writeFailed(URL)
    case resizeFailed

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let url): return "Cannot read '\(url.lastPathComponent)'"
        case .writeFailed(let url):    return "Failed to write '\(url.lastPathComponent)'"
        case .resizeFailed:            return "Failed to resize image"
        }
    }
}
