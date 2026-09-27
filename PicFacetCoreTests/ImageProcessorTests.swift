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

    private func makeImage(named name: String, width: Int = 200, height: Int = 100) throws -> URL {
        let url = dir.appendingPathComponent(name)
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
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

    @Test func onlyIfSmallerSkipsUpscale() async throws {
        let source = try makeImage(named: "photo.png")

        let result = await ImageProcessor.process([source], BatchSelection(resize: .percent(200)),
                                                  policy: OutputPolicy(onlyIfSmaller: true))

        #expect(result.succeeded == [source])
        #expect(try files() == ["photo.png"])
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
