import Foundation
import Testing
@testable import PicFacetCore

@Suite struct ServiceCommandTests {
    /// Every NSUserData in the app's Info.plist must parse.
    @Test func infoPlistCommandsParse() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PicFacet/Info.plist")
        let dict = try #require(NSDictionary(contentsOf: plist) as? [String: Any])
        let services = try #require(dict["NSServices"] as? [[String: Any]])
        let commands = services.compactMap { $0["NSUserData"] as? String }
        #expect(commands.count == 23)
        for command in commands {
            #expect(BatchSelection(serviceCommand: command) != nil, "\(command)")
        }
    }
}
