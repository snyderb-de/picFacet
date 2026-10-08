import Foundation
import ImageIO
import CoreGraphics
import Testing
@testable import PicFacetCore

/// Platform-specific checks for metadata, quality, PDF, watermark and recipe
/// behaviour that spec/cases.json can't express.
@Suite struct FeatureTests {
    let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("PicFacetFeature-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// A JPEG with GPS, EXIF camera info and an IPTC city.
    private func photoWithMetadata() throws -> URL {
        let url = dir.appendingPathComponent("geo.jpg")
        let image = try ConversionEngine.readImage(from: Fixture.image(at: dir.appendingPathComponent("seed.png"), width: 64, height: 48)).0
        let props: [String: Any] = [
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 51.5, kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 0.12, kCGImagePropertyGPSLongitudeRef as String: "W"
            ],
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifLensModel as String: "Test Lens"],
            kCGImagePropertyIPTCDictionary as String: [
                kCGImagePropertyIPTCCity as String: "London", kCGImagePropertyIPTCKeywords as String: ["kept"]
            ]
        ]
        try ConversionEngine.writeImage(image, properties: props, to: url, format: .jpeg)
        return url
    }

    private func props(_ url: URL) throws -> [String: Any] {
        try ConversionEngine.readImage(from: url).1
    }

    @Test func keepingMetadataKeepsGPS() async throws {
        let source = try photoWithMetadata()
        let result = await ImageProcessor.process([source], BatchSelection(resize: .percent(50)), policy: OutputPolicy())
        let out = try #require(result.succeeded.first)
        #expect(try props(out).keys.contains(kCGImagePropertyGPSDictionary as String))
    }

    @Test func removeLocationDropsGPSAndPlaceButKeepsCameraInfo() async throws {
        let source = try photoWithMetadata()
        let result = await ImageProcessor.process([source], BatchSelection(metadata: .location), policy: OutputPolicy())
        let out = try #require(result.succeeded.first)
        let p = try props(out)
        #expect(!p.keys.contains(kCGImagePropertyGPSDictionary as String))
        let iptc = p[kCGImagePropertyIPTCDictionary as String] as? [String: Any]
        #expect(iptc?.keys.contains(kCGImagePropertyIPTCCity as String) != true)
        let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any]
        #expect(exif?[kCGImagePropertyExifLensModel as String] as? String == "Test Lens")
    }

    @Test func removeAllDropsEverythingPersonal() async throws {
        let source = try photoWithMetadata()
        let result = await ImageProcessor.process([source], BatchSelection(metadata: .all), policy: OutputPolicy())
        let p = try props(try #require(result.succeeded.first))
        #expect(!p.keys.contains(kCGImagePropertyGPSDictionary as String))
        #expect(!p.keys.contains(kCGImagePropertyIPTCDictionary as String))
        let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any]
        #expect(exif?.keys.contains(kCGImagePropertyExifLensModel as String) != true)
    }

    @Test func lowerQualityGivesSmallerFile() async throws {
        let source = try Fixture.image(at: dir.appendingPathComponent("noise.png"), width: 300, height: 300, noisy: true)
        let high = await ImageProcessor.process([source], BatchSelection(format: .jpeg, quality: 95, rename: RenamePattern("high")), policy: OutputPolicy())
        let low = await ImageProcessor.process([source], BatchSelection(format: .jpeg, quality: 30, rename: RenamePattern("low")), policy: OutputPolicy())
        let highBytes = FileOutputManager.fileSize(try #require(high.succeeded.first))
        let lowBytes = FileOutputManager.fileSize(try #require(low.succeeded.first))
        #expect(lowBytes < highBytes / 2)
    }

    @Test func webpQualityAndLossless() async throws {
        let source = try Fixture.image(at: dir.appendingPathComponent("noise.png"), width: 200, height: 200, noisy: true)
        let low = await ImageProcessor.process([source], BatchSelection(format: .webp, quality: 30, rename: RenamePattern("low")), policy: OutputPolicy())
        let high = await ImageProcessor.process([source], BatchSelection(format: .webp, quality: 95, rename: RenamePattern("high")), policy: OutputPolicy())
        #expect(FileOutputManager.fileSize(try #require(low.succeeded.first)) < FileOutputManager.fileSize(try #require(high.succeeded.first)))

        // Quality 100 is lossless: decoded pixels match the source exactly.
        let lossless = await ImageProcessor.process([source], BatchSelection(format: .webp, quality: 100, rename: RenamePattern("exact")), policy: OutputPolicy())
        let (a, _) = try ConversionEngine.readImage(from: source)
        let (b, _) = try ConversionEngine.readImage(from: try #require(lossless.succeeded.first))
        #expect(Pixels.rgba(a) == Pixels.rgba(b))
    }

    @Test func webpKeepsTransparency() throws {
        let ctx = try #require(CGContext(data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 20))  // right half stays transparent
        let data = try WebPEncoder.encode(try #require(ctx.makeImage()), quality: 1)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pixels = Pixels.rgba(decoded)
        #expect(pixels[3] == 255)                // left: opaque red
        #expect(pixels[(19 * 4) + 3] == 0)       // right: transparent
    }

    @Test func unreachableTargetSavesSmallestWithNote() async throws {
        let source = try Fixture.image(at: dir.appendingPathComponent("noise.png"), width: 200, height: 200, noisy: true)
        let result = await ImageProcessor.process([source], BatchSelection(format: .png, maxBytes: 10), policy: OutputPolicy())
        let report = try #require(result.reports.first)
        #expect(result.succeeded.count == 1)
        #expect(report.note != nil)
    }

    @Test func pdfPagesBecomeImages() async throws {
        let pdf = dir.appendingPathComponent("doc.pdf")
        var box = CGRect(x: 0, y: 0, width: 144, height: 72)  // 2 × 1 inch
        let ctx = try #require(CGContext(pdf as CFURL, mediaBox: &box, nil))
        for _ in 0..<2 {
            ctx.beginPDFPage(nil)
            ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 10, y: 10, width: 50, height: 50))
            ctx.endPDFPage()
        }
        ctx.closePDF()

        let result = await ImageProcessor.process([pdf], BatchSelection(format: .png, dpi: 144), policy: OutputPolicy())
        #expect(result.failed.isEmpty, "\(result.failed)")
        #expect(try Fixture.files(in: dir) == ["doc-p1.png", "doc-p2.png", "doc.pdf"])
        let (page, _) = try ConversionEngine.readImage(from: dir.appendingPathComponent("doc-p1.png"))
        #expect([page.width, page.height] == [288, 144] as [Int])

        // Without a Convert format there is nothing sensible to write.
        let noFormat = await ImageProcessor.process([pdf], BatchSelection(resize: .percent(50)), policy: OutputPolicy())
        #expect(noFormat.failed.count == 1)
    }

    @Test func watermarkChangesPixelsNotSize() async throws {
        let source = try Fixture.image(at: dir.appendingPathComponent("a.png"), width: 200, height: 100)
        for mark in [Watermark(text: "© Test", position: .center, opacity: 1)] {
            let result = await ImageProcessor.process([source], BatchSelection(watermark: mark), policy: OutputPolicy())
            let out = try #require(result.succeeded.first)
            let (before, _) = try ConversionEngine.readImage(from: source)
            let (after, _) = try ConversionEngine.readImage(from: out)
            #expect([after.width, after.height] == [200, 100] as [Int])
            #expect(after.dataProvider?.data as Data? != before.dataProvider?.data as Data?)
        }
    }

    @Test func logoWatermarkFailsCleanlyWhenMissing() async throws {
        let source = try Fixture.image(at: dir.appendingPathComponent("a.png"), width: 50, height: 50)
        let mark = Watermark(logoPath: dir.appendingPathComponent("nope.png").path)
        let result = await ImageProcessor.process([source], BatchSelection(watermark: mark), policy: OutputPolicy())
        #expect(result.failed.count == 1)
        #expect(try Fixture.files(in: dir) == ["a.png"])
    }

    @Test func rotatedPhotoIsCroppedAsDisplayed() async throws {
        // 200×100 pixels tagged "rotate 90° CW": shown as 100×200.
        let seed = try Fixture.image(at: dir.appendingPathComponent("seed.png"), width: 200, height: 100)
        let (image, _) = try ConversionEngine.readImage(from: seed)
        let rotated = dir.appendingPathComponent("rot.jpg")
        try ConversionEngine.writeImage(image, properties: [kCGImagePropertyOrientation as String: 6], to: rotated, format: .jpeg)

        let result = await ImageProcessor.process([rotated], BatchSelection(crop: CropRatio(1, 2)), policy: OutputPolicy())
        let (out, props) = try ConversionEngine.readImage(from: try #require(result.succeeded.first))
        #expect([out.width, out.height] == [100, 200] as [Int])
        #expect((props[kCGImagePropertyOrientation as String] as? Int ?? 1) == 1)
    }

    @Test func renameNumbersFollowInputOrder() async throws {
        let urls = try (0..<3).map { try Fixture.image(at: dir.appendingPathComponent("s\($0).png"), width: 10, height: 10) }
        _ = await ImageProcessor.process(urls, BatchSelection(format: .jpeg, rename: RenamePattern("trip-{n}")), policy: OutputPolicy())
        let files = try Fixture.files(in: dir).filter { $0.hasPrefix("trip") }
        #expect(files == ["trip-01.jpg", "trip-02.jpg", "trip-03.jpg"])
    }

    @Test func savingsTextSummarisesWrittenFiles() {
        let a = URL(fileURLWithPath: "/tmp/a.png")
        let result = ProcessingResult(reports: [
            FileReport(source: a, outcome: .written(a), originalBytes: 1_000_000, resultBytes: 250_000),
            FileReport(source: a, outcome: .keptOriginal, originalBytes: 500, resultBytes: 900)
        ])
        #expect(result.bytesBefore == 1_000_000)
        #expect(result.savingsText?.hasPrefix("Saved 750 KB (75%)") == true)
    }
}

@Suite struct RenamePatternTests {
    @Test func outputSizeFollowsCropThenResize() {
        let s = BatchSelection(resize: .longEdge(1000), crop: CropRatio(1, 1))
        #expect(s.outputPixelSize(width: 4000, height: 3000, proportional: true) == (1000, 1000))
        #expect(BatchSelection(resize: .percent(50)).outputPixelSize(width: 400, height: 200, proportional: true) == (200, 100))
        #expect(BatchSelection().outputPixelSize(width: 0, height: 0, proportional: true) == (0, 0))
    }

    let context = RenamePattern.Context(name: "IMG_1", index: 4, count: 120, width: 800, height: 600,
                                        fileExtension: "jpg", date: Date(timeIntervalSince1970: 10 * 86_400 + 43_200))  // midday, any time zone

    @Test func tokensExpand() {
        #expect(RenamePattern("{name}-{n}-{width}x{height}.{format}").apply(context) == "IMG_1-005-800x600.jpg")
        #expect(RenamePattern("{date}").apply(context) == "1970-01-11")
    }

    @Test func unsafeCharactersAndEmptyResultsAreHandled() {
        #expect(RenamePattern("a/b:c").apply(context) == "a-b-c")
        #expect(RenamePattern("..hidden").apply(context) == "hidden")
        #expect(RenamePattern("  ").apply(context) == "IMG_1")
    }
}

@Suite struct RecipeTests {
    static let full = BatchSelection(
        format: .avif, resize: .longEdge(1600), dpi: 72, quality: 80, maxBytes: 300_000,
        metadata: .location, crop: CropRatio(4, 5),
        watermark: Watermark(text: "© Me", position: .topLeft, size: .large, opacity: 0.5),
        rename: RenamePattern("{name}-web")
    )

    @Test func recipeRoundTripsThroughJSON() throws {
        let recipe = Recipe(name: "Blog", selection: Self.full)
        let data = try JSONEncoder().encode([recipe])
        #expect(try JSONDecoder().decode([Recipe].self, from: data) == [recipe])
    }

    /// Recipes saved by an older build (fewer keys) still load.
    @Test func olderRecipesDecode() throws {
        let json = #"[{"id":"7C9B1C1E-2D59-4B0A-9E0C-0A6E0A6E0A6E","name":"Old","selection":{"format":"png","dpi":300}}]"#
        let recipes = try JSONDecoder().decode([Recipe].self, from: Data(json.utf8))
        #expect(recipes.first?.selection == BatchSelection(format: .png, dpi: 300))
    }

    @Test func draftRebuildsTheSelection() {
        #expect(OperationDraft(selection: Self.full).selection == Self.full)
        let custom = BatchSelection(resize: .percent(33), maxBytes: 123_000)
        #expect(OperationDraft(selection: custom).selection == custom)
        let logo = BatchSelection(watermark: Watermark(logoPath: "/tmp/logo.png"))
        #expect(OperationDraft(selection: logo).selection == logo)
    }

    @Test func settingsStoreRecipesAndFolders() {
        let suite = "com.picfacet.tests.recipes"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = PicFacetSettings(defaults: defaults)

        #expect(settings.recipes.isEmpty)
        let recipe = Recipe(name: "Web", selection: Self.full)
        settings.recipes = [recipe]
        #expect(settings.recipe(id: recipe.id) == recipe)

        let folder = WatchedFolder(path: "/tmp/in", recipeID: recipe.id)
        settings.watchedFolders = [folder]
        #expect(settings.watchedFolders == [folder])

        let token = settings.recipeRunToken
        #expect(token.count >= 32)
        #expect(settings.recipeRunToken == token)
    }

    @Test func watchedFolderPolicyNeverTouchesInputs() {
        let recipe = Recipe(name: "Web", selection: BatchSelection(format: .jpeg))
        var folder = WatchedFolder(path: "/tmp/in", recipeID: recipe.id, deleteOriginals: true)
        let policy = folder.policy(from: OutputPolicy(overwriteSource: true, deleteOriginalAfterConvert: true), recipe: recipe)
        #expect(!policy.overwriteSource)
        #expect(!policy.deleteOriginalAfterConvert)
        #expect(!policy.deleteSourceAfterWrite)  // deletion waits for every recipe
        #expect(policy.customOutputFolder?.path == "/tmp/in/Processed")

        folder.recipeIDs.append(UUID())
        #expect(folder.policy(from: OutputPolicy(), recipe: recipe).customOutputFolder?.path == "/tmp/in/Processed/Web")
    }

    /// One image, two recipes: two outputs from the original, each in its
    /// recipe's folder. Originals go only after every recipe wrote.
    @Test func watchedFolderFansOutAndDeletesAfterAllRecipes() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PicFacetWatch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let thumb = Recipe(name: "Thumb", selection: BatchSelection(format: .webp, resize: .longEdge(20)))
        let print = Recipe(name: "Print", selection: BatchSelection(format: .tiff, dpi: 300))
        let keep = WatchedFolder(path: dir.path, recipeIDs: [thumb.id, print.id])
        var delete = keep
        delete.deleteOriginals = true

        let a = try Fixture.image(at: dir.appendingPathComponent("a.png"), width: 80, height: 40)
        let kept = await keep.process([a], recipes: [thumb, print], base: OutputPolicy())
        #expect(kept.succeeded.count == 2)
        #expect(FileManager.default.fileExists(atPath: a.path))

        let b = try Fixture.image(at: dir.appendingPathComponent("b.png"), width: 80, height: 40)
        _ = await delete.process([b], recipes: [thumb, print], base: OutputPolicy())
        #expect(!FileManager.default.fileExists(atPath: b.path))
        #expect(try Fixture.files(in: dir) == [
            "Processed/Print/a.tif", "Processed/Print/b.tif",
            "Processed/Thumb/a.webp", "Processed/Thumb/b.webp", "a.png"
        ])
        let (small, _) = try ConversionEngine.readImage(from: dir.appendingPathComponent("Processed/Thumb/b.webp"))
        #expect([small.width, small.height] == [20, 10] as [Int])

        // One recipe's result discarded (not smaller): the original stays.
        let c = try Fixture.image(at: dir.appendingPathComponent("c.png"), width: 80, height: 40)
        _ = await delete.process([c], recipes: [thumb, print], base: OutputPolicy(onlyIfSmaller: true))
        #expect(FileManager.default.fileExists(atPath: c.path))
    }

    @Test func singleRecipeFoldersStillDecode() throws {
        let json = #"[{"id":"7C9B1C1E-2D59-4B0A-9E0C-0A6E0A6E0A6E","path":"/tmp/in","recipeID":"7C9B1C1E-2D59-4B0A-9E0C-0A6E0A6E0A6F","isEnabled":true}]"#
        let folder = try #require(try JSONDecoder().decode([WatchedFolder].self, from: Data(json.utf8)).first)
        #expect(folder.recipeIDs.map(\.uuidString) == ["7C9B1C1E-2D59-4B0A-9E0C-0A6E0A6E0A6F"])
        let again = try JSONDecoder().decode(WatchedFolder.self, from: JSONEncoder().encode(folder))
        #expect(again == folder)
    }

    @Test func olderWatchedFoldersDecodeWithDeleteOff() throws {
        let json = #"[{"id":"7C9B1C1E-2D59-4B0A-9E0C-0A6E0A6E0A6E","path":"/tmp/in","recipeID":"7C9B1C1E-2D59-4B0A-9E0C-0A6E0A6E0A6F","isEnabled":true}]"#
        let folders = try JSONDecoder().decode([WatchedFolder].self, from: Data(json.utf8))
        #expect(folders.first?.deleteOriginals == false)
    }

    @Test func watchedFolderSeesOnlyNewImages() {
        let urls = ["a.jpg", "b.png", ".picfacet-x.png", "notes.txt", "c.pdf"].map { URL(fileURLWithPath: "/tmp/in/\($0)") }
        let new = WatchedFolder.newFiles(in: urls, known: ["/tmp/in/a.jpg"])
        #expect(new.map(\.lastPathComponent) == ["b.png", "c.pdf"])
    }
}

/// Straight RGBA bytes in sRGB, for exact pixel comparisons.
enum Pixels {
    static func rgba(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ctx = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }
}
