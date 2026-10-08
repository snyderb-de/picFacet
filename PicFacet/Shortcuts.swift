import AppIntents
import Foundation
import UniformTypeIdentifiers
import PicFacetCore

// Shortcuts app actions. Both take images (or PDFs) and return the processed
// files, so a shortcut decides where they go: Save File, Share, Mail…
// Inputs are copied to a temporary folder first; originals are never changed.

// MARK: - Actions

struct ProcessImagesIntent: AppIntent {
    static let title: LocalizedStringResource = "Process Images"
    static let description = IntentDescription(
        "Convert, resize, compress and clean up images with PicFacet. Returns the processed files.",
        categoryName: "Images"
    )

    @Parameter(title: "Images", supportedContentTypes: [.image, .pdf])
    var images: [IntentFile]

    @Parameter(title: "Format")
    var format: ImageFormatOption?

    @Parameter(title: "Fit Long Edge (px)", inclusiveRange: (1, 20_000))
    var longEdge: Int?

    @Parameter(title: "Quality (1–100)", inclusiveRange: (1, 100))
    var quality: Int?

    @Parameter(title: "Max File Size (KB)", inclusiveRange: (1, 1_000_000))
    var maxKB: Int?

    @Parameter(title: "Metadata", default: .keep)
    var metadata: MetadataOption

    static var parameterSummary: some ParameterSummary {
        Summary("Process \(\.$images)") {
            \.$format
            \.$longEdge
            \.$quality
            \.$maxKB
            \.$metadata
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let selection = BatchSelection(
            format: format?.format,
            resize: longEdge.map { .longEdge($0) },
            quality: quality,
            maxBytes: maxKB.map { $0 * 1_000 },
            metadata: metadata.mode
        )
        guard selection.hasSelection else {
            throw ShortcutError.message("Choose at least one option: a format, size, quality, file size limit or metadata change.")
        }
        return .result(value: try await ShortcutRunner.run(images, selection))
    }
}

struct RunRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Run PicFacet Recipe"
    static let description = IntentDescription(
        "Runs a saved PicFacet recipe on images. Returns the processed files.",
        categoryName: "Images"
    )

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    @Parameter(title: "Images", supportedContentTypes: [.image, .pdf])
    var images: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$recipe) on \(\.$images)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        guard let saved = PicFacetSettings.shared.recipe(id: recipe.id) else {
            throw ShortcutError.message("That recipe no longer exists. Pick another one in PicFacet's Settings.")
        }
        return .result(value: try await ShortcutRunner.run(images, saved.selection))
    }
}

struct PicFacetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunRecipeIntent(),
            phrases: ["Run a \(.applicationName) recipe"],
            shortTitle: "Run Recipe",
            systemImageName: "wand.and.stars"
        )
        AppShortcut(
            intent: ProcessImagesIntent(),
            phrases: ["Process images with \(.applicationName)"],
            shortTitle: "Process Images",
            systemImageName: "photo.stack"
        )
    }
}

// MARK: - Parameter types

enum ImageFormatOption: String, AppEnum {
    case jpeg, png, heic, avif, webp, tiff, gif, bmp, pdf

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Image Format"
    static let caseDisplayRepresentations: [ImageFormatOption: DisplayRepresentation] = [
        .jpeg: "JPEG", .png: "PNG", .heic: "HEIC", .avif: "AVIF", .webp: "WebP",
        .tiff: "TIFF", .gif: "GIF", .bmp: "BMP", .pdf: "PDF"
    ]

    var format: ImageFormat { ImageFormat(rawValue: rawValue)! }
}

enum MetadataOption: String, AppEnum {
    case keep, location, all

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Metadata"
    static let caseDisplayRepresentations: [MetadataOption: DisplayRepresentation] = [
        .keep: "Keep All", .location: "Remove Location", .all: "Remove All"
    ]

    var mode: MetadataMode? { MetadataMode(rawValue: rawValue) }
}

struct RecipeEntity: AppEntity {
    let id: UUID
    let name: String
    let summary: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "PicFacet Recipe"
    static let defaultQuery = RecipeQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    init(_ recipe: Recipe) {
        id = recipe.id
        name = recipe.name
        summary = recipe.selection.summary
    }
}

struct RecipeQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [RecipeEntity] {
        PicFacetSettings.shared.recipes.filter { identifiers.contains($0.id) }.map(RecipeEntity.init)
    }

    func suggestedEntities() async throws -> [RecipeEntity] {
        PicFacetSettings.shared.recipes.map(RecipeEntity.init)
    }
}

enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text): "\(text)"
        }
    }
}

// MARK: - Running

enum ShortcutRunner {
    /// Copies the inputs to a temporary folder, processes them there and
    /// returns the results in input order. A file kept because the result
    /// wasn't smaller is returned unchanged.
    static func run(_ files: [IntentFile], _ selection: BatchSelection) async throws -> [IntentFile] {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("PicFacet-Shortcuts-\(UUID().uuidString)", isDirectory: true)
        let inputDir = work.appendingPathComponent("in", isDirectory: true)
        let outputDir = work.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var inputs: [URL] = []
        var used: Set<String> = []
        for (index, file) in files.enumerated() {
            var name = file.filename.isEmpty ? "image-\(index + 1).\(file.type?.preferredFilenameExtension ?? "jpg")" : file.filename
            // Distinct names, so two "IMG_0001.jpg" from different folders don't collide.
            if used.contains(name.lowercased()) {
                let url = URL(fileURLWithPath: name)
                name = "\(url.deletingPathExtension().lastPathComponent)-\(index + 1).\(url.pathExtension)"
            }
            used.insert(name.lowercased())
            let url = inputDir.appendingPathComponent(name)
            try file.data.write(to: url)
            inputs.append(url)
        }

        var policy = PicFacetSettings.shared.outputPolicy
        policy.overwriteSource = false
        policy.deleteOriginalAfterConvert = false
        policy.saveUnsupportedAsJPEG = true
        policy.customOutputFolder = outputDir

        let tracked = RunProgress.shared.begin(total: inputs.count)
        let result = await ImageProcessor.process(inputs, selection, policy: policy) { p in
            RunProgress.shared.update(tracked, completed: p.completed)
        }
        RunProgress.shared.end(tracked)
        if result.succeeded.isEmpty && result.keptOriginal.isEmpty, let failure = result.failed.first {
            throw ShortcutError.message("\(failure.url.lastPathComponent): \(failure.error.localizedDescription)")
        }

        let bySource = Dictionary(result.reports.map { ($0.source.path, $0) }, uniquingKeysWith: { a, _ in a })
        return inputs.flatMap { input -> [URL] in
            guard let report = bySource[input.path] else { return [] }
            switch report.outcome {
            case .written(let url): return [url] + report.extraOutputs
            case .keptOriginal: return [input]
            case .failed: return []
            }
        }
        .map { IntentFile(fileURL: $0, filename: $0.lastPathComponent) }
    }
}
