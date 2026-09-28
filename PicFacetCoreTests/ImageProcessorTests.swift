import Foundation
import ImageIO
import Testing
@testable import PicFacetCore

/// Platform-specific pipeline behaviour. Portable cases live in spec/cases.json
/// (run by SharedSpecTests).
@Suite struct ImageProcessorTests {
    @Test func unreadableFileFailsAndProgressCountsEveryFile() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PicFacetTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let good = try Fixture.image(at: dir.appendingPathComponent("a.png"), width: 20, height: 10)
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
