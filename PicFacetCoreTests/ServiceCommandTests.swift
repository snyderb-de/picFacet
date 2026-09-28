import Foundation
import Testing
@testable import PicFacetCore

@Suite struct ServiceCommandTests {
    @Test(arguments: [
        ("convert:jpeg", BatchSelection(format: .jpeg)),
        ("convert:HEIC", BatchSelection(format: .heic)),
        ("resize:50%", BatchSelection(resize: .percent(50))),
        ("width:800", BatchSelection(resize: .width(800))),
        ("height:600", BatchSelection(resize: .height(600))),
        ("dpi:300", BatchSelection(dpi: 300)),
        ("convert:png;resize:25%;dpi:72", BatchSelection(format: .png, resize: .percent(25), dpi: 72)),
        (" convert : webp ", BatchSelection(format: .webp)),
    ])
    func parses(command: String, expected: BatchSelection) {
        #expect(BatchSelection(serviceCommand: command) == expected)
    }

    @Test(arguments: ["", "convert", "convert:psd", "resize:50", "resize:0%", "width:-1", "dpi:abc", "rotate:90", "convert:png;bogus"])
    func rejects(command: String) {
        #expect(BatchSelection(serviceCommand: command) == nil)
    }

    /// Every NSUserData in the app's Info.plist must parse.
    @Test func infoPlistCommandsParse() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PicFacet/Info.plist")
        let dict = try #require(NSDictionary(contentsOf: plist) as? [String: Any])
        let services = try #require(dict["NSServices"] as? [[String: Any]])
        let commands = services.compactMap { $0["NSUserData"] as? String }
        #expect(commands.count == 14)
        for command in commands {
            #expect(BatchSelection(serviceCommand: command) != nil, "\(command)")
        }
    }
}
