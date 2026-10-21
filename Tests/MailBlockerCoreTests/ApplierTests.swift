import XCTest
@testable import MailBlockerCore
import MailBlockerShared

final class ApplierTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        SharedStorage.containerOverride = folder
    }

    override func tearDownWithError() throws {
        SharedStorage.containerOverride = nil
        try? FileManager.default.removeItem(at: folder)
    }

    func testApplySavesTheJSONAndTheSourceForTheExtension() throws {
        let outcome = RulesApplier.apply("||pixel.example.com^$image\n||track.example.net^")
        XCTAssertEqual(outcome.summary.entries, 2)
        XCTAssertEqual(outcome.status, "Saved 2 entries. Restart Mail.")
        XCTAssertEqual(SharedStorage.loadRules(), outcome.summary.json)
        XCTAssertEqual(SharedStorage.loadSource(), "||pixel.example.com^$image\n||track.example.net^")
    }

    func testStatusUsesTheSingularForOneEntry() {
        XCTAssertEqual(RulesApplier.apply("||a.example^").status, "Saved 1 entry. Restart Mail.")
    }

    func testApplyingAnEmptyListSavesTheListThatBlocksNothing() {
        let outcome = RulesApplier.apply("! nothing here")
        XCTAssertEqual(outcome.summary.entries, 0)
        XCTAssertEqual(SharedStorage.loadRules(), SharedStorage.emptyRules)
    }

    func testApplyWritesALogLine() {
        _ = RulesApplier.apply("||a.example^")
        XCTAssertTrue(SharedStorage.readLog().contains("app: saved 1 entries"))
    }

    func testApplyReportsWhenThereIsNowhereToSave() {
        SharedStorage.containerOverride = nil
        let outcome = RulesApplier.apply("||a.example^")
        XCTAssertTrue(outcome.status.hasPrefix("Could not save"))
        XCTAssertEqual(outcome.summary.entries, 1, "the conversion itself still happened")
    }

    func testTheLastApplyWins() {
        _ = RulesApplier.apply("||first.example^")
        _ = RulesApplier.apply("||second.example^\n||third.example^")
        XCTAssertEqual(SharedStorage.loadSource(), "||second.example^\n||third.example^")
    }

    func testWordingUsesSingularOnlyForOne() {
        XCTAssertEqual(Wording.count(0, "rule", "rules"), "0 rules")
        XCTAssertEqual(Wording.count(1, "rule", "rules"), "1 rule")
        XCTAssertEqual(Wording.count(2, "entry", "entries"), "2 entries")
    }

    func testHeadline() {
        XCTAssertEqual(Converter.convert("||a.example^").headline, "1 rule → 1 entry")
        XCTAssertEqual(Converter.convert("||a.example^\n||b.example^").headline, "2 rules → 2 entries")
        XCTAssertEqual(Converter.convert("").headline, "0 rules → 0 entries")
    }
}
