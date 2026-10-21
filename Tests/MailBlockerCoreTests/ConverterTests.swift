import XCTest
@testable import MailBlockerCore
import MailBlockerShared

final class ConverterTests: XCTestCase {
    private func entries(_ summary: ConversionSummary) throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: summary.json)
        return try XCTUnwrap(object as? [[String: Any]])
    }

    func testNetworkRuleBecomesABlockEntry() throws {
        let summary = Converter.convert("||pixel.example.com^$image")
        XCTAssertEqual(summary.sourceRules, 1)
        XCTAssertEqual(summary.entries, 1)
        XCTAssertTrue(summary.warnings.isEmpty)
        let action = try XCTUnwrap(try entries(summary).first?["action"] as? [String: Any])
        XCTAssertEqual(action["type"] as? String, "block")
    }

    func testCommentsAndBlankLinesAreIgnored() {
        let summary = Converter.convert("! a comment\n\n   \n||pixel.example.com^")
        XCTAssertEqual(summary.sourceRules, 1)
        XCTAssertEqual(summary.entries, 1)
    }

    func testNoRulesProducesAListThatBlocksNothing() throws {
        let summary = Converter.convert("! only a comment")
        XCTAssertEqual(summary.sourceRules, 0)
        XCTAssertEqual(summary.entries, 0)
        XCTAssertFalse(summary.warnings.isEmpty)
        XCTAssertEqual(summary.json, SharedStorage.emptyRules)
        XCTAssertEqual(try entries(summary).count, 1)
    }

    func testRuleTheConverterDropsFallsBackToTheEmptyList() {
        // $removeparam has no WebKit equivalent: the converter produces nothing for it.
        let summary = Converter.convert("||example.org^$removeparam=id")
        XCTAssertEqual(summary.entries, 0)
        XCTAssertEqual(summary.json, SharedStorage.emptyRules)
        XCTAssertFalse(summary.warnings.isEmpty)
    }

    func testPositiveDomainRuleIsStillConverted() {
        // Converted and shipped; in Mail it never fires, which is why this is a talk and not a test of Mail.
        let summary = Converter.convert("||pixel.example.com^$domain=sender.example")
        XCTAssertEqual(summary.entries, 1)
    }

    func testEmptyListIsAValidWebKitArray() throws {
        let object = try JSONSerialization.jsonObject(with: SharedStorage.emptyRules)
        XCTAssertEqual((object as? [Any])?.count, 1)
    }
}
