import Foundation
import ImageIO
import Testing
@testable import PicFacetCore

/// Runs the platform-neutral cases in spec/cases.json. Any port of PicFacet
/// (see docs/roadmap/windows-port.md) must pass the same file.
@Suite struct SharedSpecTests {

    // MARK: - Spec model

    struct Spec: Decodable {
        struct ServiceCommands: Decodable {
            struct Valid: Decodable { let command: String; let selection: SelectionSpec }
            let valid: [Valid]
            let invalid: [String]
        }
        let serviceCommands: ServiceCommands
        let pipeline: [PipelineCase]
    }

    struct SelectionSpec: Decodable {
        struct Resize: Decodable { let percent: Int?; let width: Int?; let height: Int?; let longEdge: Int? }
        let format: String?
        let resize: Resize?
        let dpi: Int?
        let quality: Int?
        let maxBytes: Int?
        let metadata: String?
        let crop: String?
        let rename: String?

        var selection: BatchSelection {
            let resizeOp: ResizeOperation? = resize.flatMap { r in
                if let p = r.percent { return .percent(p) }
                if let w = r.width { return .width(w) }
                if let h = r.height { return .height(h) }
                if let e = r.longEdge { return .longEdge(e) }
                return nil
            }
            return BatchSelection(
                format: format.flatMap { ImageFormat(fileExtension: $0) }, resize: resizeOp, dpi: dpi,
                quality: quality, maxBytes: maxBytes, metadata: metadata.flatMap(MetadataMode.init(rawValue:)),
                crop: crop.flatMap { CropRatio(label: $0) }, rename: rename.map(RenamePattern.init)
            )
        }
    }

    struct PipelineCase: Decodable, CustomTestStringConvertible {
        struct Source: Decodable { let name: String; let width: Int; let height: Int; let noisy: Bool? }
        struct Policy: Decodable {
            let overwriteSource: Bool?
            let onlyIfSmaller: Bool?
            let deleteOriginalAfterConvert: Bool?
            let isProportional: Bool?
            let customOutputFolder: String?
        }
        struct Expect: Decodable {
            /// "written" or "keptOriginal".
            let outcome: String?
            let files: [String]?
            let result: String?
            let pixels: [Int]?
            let dpi: Int?
            let sourceUnchanged: Bool?
            /// The output is at most this many bytes.
            let maxBytes: Int?
        }
        let name: String
        let source: Source
        let existing: [String]?
        let selection: SelectionSpec
        let policy: Policy
        let expect: Expect

        var testDescription: String { name }
    }

    static let spec: Spec = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("spec/cases.json")
        return try! JSONDecoder().decode(Spec.self, from: Data(contentsOf: url))
    }()

    // MARK: - Service commands

    @Test(arguments: spec.serviceCommands.valid.map { ($0.command, $0.selection.selection) })
    func serviceCommandParses(command: String, expected: BatchSelection) {
        #expect(BatchSelection(serviceCommand: command) == expected)
    }

    @Test(arguments: spec.serviceCommands.invalid)
    func serviceCommandRejects(command: String) {
        #expect(BatchSelection(serviceCommand: command) == nil)
    }

    // MARK: - Pipeline

    @Test(arguments: spec.pipeline)
    func pipeline(_ c: PipelineCase) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PicFacetSpec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = try Fixture.image(at: dir.appendingPathComponent(c.source.name),
                                       width: c.source.width, height: c.source.height,
                                       noisy: c.source.noisy ?? false)
        for name in c.existing ?? [] {
            _ = try Fixture.image(at: dir.appendingPathComponent(name), width: 10, height: 10)
        }
        let before = try Data(contentsOf: source)

        var policy = OutputPolicy(
            overwriteSource: c.policy.overwriteSource ?? false,
            onlyIfSmaller: c.policy.onlyIfSmaller ?? false,
            deleteOriginalAfterConvert: c.policy.deleteOriginalAfterConvert ?? false,
            isProportional: c.policy.isProportional ?? true
        )
        if let folder = c.policy.customOutputFolder {
            let out = dir.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            policy.customOutputFolder = out
        }

        let result = await ImageProcessor.process([source], c.selection.selection, policy: policy)
        #expect(result.failed.isEmpty, "\(result.failed)")

        if let files = c.expect.files {
            #expect(try Fixture.files(in: dir) == files)
        }
        let report = try #require(result.reports.first)
        let output: URL
        switch report.outcome {
        case .written(let url):
            output = url
            #expect(c.expect.outcome ?? "written" == "written")
        case .keptOriginal:
            output = report.source
            #expect(c.expect.outcome == "keptOriginal")
        case .failed(let error):
            Issue.record(error)
            return
        }
        if let expected = c.expect.result {
            #expect(output.standardizedFileURL == dir.appendingPathComponent(expected).standardizedFileURL)
        }
        if let pixels = c.expect.pixels {
            let (image, _) = try ConversionEngine.readImage(from: output)
            #expect([image.width, image.height] == pixels)
        }
        if let dpi = c.expect.dpi {
            let (_, props) = try ConversionEngine.readImage(from: output)
            #expect((props[kCGImagePropertyDPIWidth as String] as? Double)?.rounded() == Double(dpi))
            #expect((props[kCGImagePropertyDPIHeight as String] as? Double)?.rounded() == Double(dpi))
        }
        if let maxBytes = c.expect.maxBytes {
            #expect(FileOutputManager.fileSize(output) <= maxBytes)
            #expect(report.note == nil)
        }
        if c.expect.sourceUnchanged == true {
            #expect(try Data(contentsOf: source) == before)
        }
    }
}

enum Fixture {
    /// Flat-colour image, or per-pixel noise when `noisy` (compresses poorly).
    static func image(at url: URL, width: Int, height: Int, noisy: Bool = false) throws -> URL {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if noisy {
            for x in 0..<width { for y in 0..<height where Bool.random() {
                ctx.setFillColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            } }
        }
        let format = ImageFormat(fileExtension: url.pathExtension)!
        try ConversionEngine.writeImage(ctx.makeImage()!, properties: [:], to: url, format: format)
        return url
    }

    /// Every file under `dir` (hidden ones included), relative and sorted.
    static func files(in dir: URL) throws -> [String] {
        let root = dir.standardizedFileURL.path + "/"
        let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])!
        return enumerator.compactMap { item -> String? in
            guard let url = item as? URL,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            return String(url.standardizedFileURL.path.dropFirst(root.count))
        }.sorted()
    }
}
