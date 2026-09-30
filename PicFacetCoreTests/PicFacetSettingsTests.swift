import Foundation
import Testing
@testable import PicFacetCore

/// Serialized: every test shares one scratch defaults suite, wiped before each
/// test, so runs leave a single empty plist behind instead of one per test.
@Suite(.serialized) struct PicFacetSettingsTests {
    static let suiteName = "com.picfacet.tests.settings"
    let settings: PicFacetSettings

    init() {
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        defaults.removePersistentDomain(forName: Self.suiteName)
        settings = PicFacetSettings(defaults: defaults)
    }

    @Test func freshSettingsGiveDefaultPolicy() {
        let policy = settings.outputPolicy
        #expect(!policy.overwriteSource)
        #expect(!policy.onlyIfSmaller)
        #expect(!policy.deleteOriginalAfterConvert)
        #expect(policy.isProportional)
        #expect(policy.customOutputFolder == nil)
    }

    @Test func policySnapshotsStoredValues() {
        settings.overwriteSource = true
        settings.onlyIfSmaller = true
        settings.deleteOriginalAfterConvert = true
        settings.isProportional = false
        settings.customOutputFolder = "/tmp/out"

        let policy = settings.outputPolicy
        #expect(policy.overwriteSource)
        #expect(policy.onlyIfSmaller)
        #expect(policy.deleteOriginalAfterConvert)
        #expect(!policy.isProportional)
        #expect(policy.customOutputFolder == URL(fileURLWithPath: "/tmp/out", isDirectory: true))
    }

    @Test func policyIsASnapshot() {
        let before = settings.outputPolicy
        settings.overwriteSource = true
        #expect(!before.overwriteSource)
    }

    @Test func draftDefaultsFollowSettings() {
        settings.defaultFormat = .webp
        settings.defaultResizePercent = 75
        settings.defaultDPI = 300

        let draft = OperationDraft.defaults(from: settings)
        #expect(draft.selection == BatchSelection(format: .webp, resize: .percent(75), dpi: 300))
    }

    @Test func noChangeDefaultsRoundTrip() {
        settings.defaultFormat = nil
        settings.defaultResizePercent = nil
        settings.defaultDPI = nil

        #expect(settings.defaultFormat == nil)
        #expect(settings.defaultResizePercent == nil)
        #expect(settings.defaultDPI == nil)
        #expect(OperationDraft.defaults(from: settings) == OperationDraft())
    }

    @Test func nonPresetResizeDefaultFallsBackTo50() {
        settings.defaultResizePercent = 33
        #expect(OperationDraft.defaults(from: settings).resizeMode == .percent(50))
    }
}
