import Foundation
import ImageIO
import Testing
@testable import PicFacetCore

@Suite struct ImageProcessorTests {
    let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PicFacetTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Fixtures

    private func makeImage(named name: String, width: Int = 200, height: Int = 100, noisy: Bool = false) throws -> URL {
        let url = dir.appendingPathComponent(name)
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if noisy {
            var rng = SystemRandomNumberGenerator()
            for x in 0..<width { for y in 0..<height where Bool.random(using: &rng) {
                ctx.setFillColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            } }
        }
        let format = ImageFormat(fileExtension: url.pathExtension)!
        try ConversionEngine.writeImage(ctx.makeImage()!, properties: [:], to: url, format: format)
        return url
    }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    private func pixelSize(_ url: URL) throws -> (Int, Int) {
        let (image, _) = try ConversionEngine.readImage(from: url)
        return (image.width, image.height)
    }

    // MARK: - Tests

    @Test func chainedStepsWriteOneFile() async throws {
        let source = try makeImage(named: "photo.jpg")
        let selection = BatchSelection(format: .png, resize: .percent(50), dpi: 300)

        let result = await ImageProcessor.process([source], selection, policy: OutputPolicy())

        #expect(result.failed.isEmpty)
        #expect(try files() == ["photo.jpg", "photo.png"])
        let output = try #require(result.succeeded.first)
        #expect(output.lastPathComponent == "photo.png")
        #expect(try pixelSize(output) == (100, 50))

        let (_, props) = try ConversionEngine.readImage(from: output)
        #expect((props[kCGImagePropertyDPIWidth as String] as? Double)?.rounded() == 300)
    }

    @Test(arguments: ["photo.png", "photo.jpg", "photo.tif", "photo.heic"])
    func dpiIsWritten(name: String) async throws {
        let source = try makeImage(named: name)

        let result = await ImageProcessor.process([source], BatchSelection(dpi: 300), policy: OutputPolicy())

        let (_, props) = try ConversionEngine.readImage(from: result.succeeded[0])
        #expect((props[kCGImagePropertyDPIWidth as String] as? Double)?.rounded() == 300)
        #expect((props[kCGImagePropertyDPIHeight as String] as? Double)?.rounded() == 300)
    }

    @Test func inPlaceResizeWritesSuffixedCopy() async throws {
        let source = try makeImage(named: "photo.png")

        let result = await ImageProcessor.process([source], BatchSelection(resize: .width(50)), policy: OutputPolicy())

        #expect(try files() == ["photo-picfacet.png", "photo.png"])
        #expect(try pixelSize(result.succeeded[0]) == (50, 25))
    }

    @Test func overwriteSourceReplacesFile() async throws {
        let source = try makeImage(named: "photo.png")

        _ = await ImageProcessor.process([source], BatchSelection(resize: .percent(25)),
                                         policy: OutputPolicy(overwriteSource: true))

        #expect(try files() == ["photo.png"])
        #expect(try pixelSize(source) == (50, 25))
    }

    @Test func onlyIfSmallerKeepsSmallerFile() async throws {
        let source = try makeImage(named: "photo.png", noisy: true)

        let result = await ImageProcessor.process([source], BatchSelection(resize: .percent(25)),
                                                  policy: OutputPolicy(onlyIfSmaller: true))

        #expect(result.succeeded == [dir.appendingPathComponent("photo-picfacet.png")])
        #expect(try files() == ["photo-picfacet.png", "photo.png"])
    }

    @Test func onlyIfSmallerDiscardsLargerFile() async throws {
        // A flat-colour PNG compresses far better than uncompressed TIFF
        let source = try makeImage(named: "photo.png")

        let result = await ImageProcessor.process([source], BatchSelection(format: .tiff),
                                                  policy: OutputPolicy(onlyIfSmaller: true, deleteOriginalAfterConvert: true))

        #expect(result.succeeded == [source])
        #expect(try files() == ["photo.png"]) // no output, no staging file, original kept
    }

    @Test func onlyIfSmallerNeverTouchesSourceWhenOverwriting() async throws {
        let source = try makeImage(named: "photo.png")
        let before = try Data(contentsOf: source)

        _ = await ImageProcessor.process([source], BatchSelection(resize: .percent(300)),
                                         policy: OutputPolicy(overwriteSource: true, onlyIfSmaller: true))

        #expect(try Data(contentsOf: source) == before)
        #expect(try files() == ["photo.png"])
    }

    @Test func onlyIfSmallerIgnoresDpiOnlyChanges() async throws {
        let source = try makeImage(named: "photo.png")

        let result = await ImageProcessor.process([source], BatchSelection(dpi: 300),
                                                  policy: OutputPolicy(onlyIfSmaller: true))

        #expect(result.succeeded == [dir.appendingPathComponent("photo-picfacet.png")])
    }

    @Test func deleteOriginalAfterConvert() async throws {
        let source = try makeImage(named: "photo.png")

        _ = await ImageProcessor.process([source], BatchSelection(format: .jpeg),
                                         policy: OutputPolicy(deleteOriginalAfterConvert: true))

        #expect(try files() == ["photo.jpg"])
    }

    @Test func customOutputFolder() async throws {
        let source = try makeImage(named: "photo.png")
        let out = dir.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let result = await ImageProcessor.process([source], BatchSelection(dpi: 150),
                                                  policy: OutputPolicy(customOutputFolder: out))

        #expect(result.succeeded == [out.appendingPathComponent("photo.png")])
    }

    @Test func unreadableFileFailsAndProgressCountsEveryFile() async throws {
        let good = try makeImage(named: "a.png")
        let bad = dir.appendingPathComponent("missing.png")
        let progress = ProgressLog()

        let result = await ImageProcessor.process([good, bad], BatchSelection(format: .jpeg),
                                                  policy: OutputPolicy()) { done, total in
            progress.values.append("\(done)/\(total)")
        }

        #expect(result.succeeded.count == 1)
        #expect(result.failed.map(\.url) == [bad])
        #expect(await progress.values == ["1/2", "2/2"])
    }
}

@MainActor private final class ProgressLog {
    var values: [String] = []
}

@Suite struct OperationDraftTests {
    @Test func emptyDraftHasNoSelection() {
        let draft = OperationDraft()
        #expect(draft.selection == nil)
        #expect(draft.summary == "Choose at least one operation to continue.")
    }

    @Test func presetPercentNeedsNoEntry() {
        let draft = OperationDraft(resizeMode: .percent(50))
        #expect(draft.entryIsValid)
        #expect(draft.selection == BatchSelection(resize: .percent(50)))
    }

    @Test func typedModeIsInvalidUntilPositive() {
        var draft = OperationDraft(format: .png, resizeMode: .width)
        #expect(!draft.entryIsValid)
        #expect(draft.selection == nil)
        #expect(draft.summary == "Enter a positive resize value to continue.")

        draft.entryText = "0"
        #expect(draft.selection == nil)

        draft.entryText = "800"
        #expect(draft.selection == BatchSelection(format: .png, resize: .width(800)))
        #expect(draft.summary == "Convert to PNG + Set width to 800 px")
    }

    @Test func entryKeepsDigitsOnlyAndCaps() {
        var draft = OperationDraft(resizeMode: .height)
        draft.entryText = "12a3456789"
        #expect(draft.entryText == "12345")
    }

    @Test func entriesAreKeptPerMode() {
        var draft = OperationDraft(resizeMode: .width)
        draft.entryText = "640"
        draft.resizeMode = .height
        #expect(draft.entryText == "")
        draft.entryText = "480"
        draft.resizeMode = .width
        #expect(draft.resize == .width(640))
    }

    @Test func customPercentBecomesPercent() {
        var draft = OperationDraft(resizeMode: .customPercent, dpi: 300)
        draft.entryText = "33"
        #expect(draft.selection == BatchSelection(resize: .percent(33), dpi: 300))
    }
}
