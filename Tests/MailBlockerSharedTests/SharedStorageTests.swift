import XCTest
@testable import MailBlockerShared

final class SharedStorageTests: XCTestCase {
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

    func testNothingSavedYet() {
        XCTAssertNil(SharedStorage.loadRules())
        XCTAssertNil(SharedStorage.loadSource())
        XCTAssertEqual(SharedStorage.readLog(), "")
    }

    func testSaveThenLoadReturnsTheSameBytesAndSource() throws {
        let json = Data(#"[{"trigger":{"url-filter":"x"},"action":{"type":"block"}}]"#.utf8)
        try SharedStorage.save(json: json, source: "||x^")
        XCTAssertEqual(SharedStorage.loadRules(), json)
        XCTAssertEqual(SharedStorage.loadSource(), "||x^")
    }

    func testSaveReplacesThePreviousRules() throws {
        try SharedStorage.save(json: Data("[1]".utf8), source: "first")
        try SharedStorage.save(json: Data("[2]".utf8), source: "second")
        XCTAssertEqual(SharedStorage.loadRules(), Data("[2]".utf8))
        XCTAssertEqual(SharedStorage.loadSource(), "second")
    }

    func testSourceKeepsNonASCIIText() throws {
        try SharedStorage.save(json: Data("[]".utf8), source: "! правило\n||пример.рф^")
        XCTAssertEqual(SharedStorage.loadSource(), "! правило\n||пример.рф^")
    }

    func testSaveWithoutAContainerThrows() {
        SharedStorage.containerOverride = nil  // the test process has no App Group entitlement
        XCTAssertThrowsError(try SharedStorage.save(json: Data(), source: ""))
    }

    func testLogAppendsLinesInOrder() {
        SharedStorage.log("first")
        SharedStorage.log("second")
        let lines = SharedStorage.readLog().split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasSuffix("first"))
        XCTAssertTrue(lines[1].hasSuffix("second"))
        XCTAssertTrue(lines[0].hasPrefix("["))
    }

    func testEmptyRulesIsAValidNonEmptyWebKitArray() throws {
        let object = try JSONSerialization.jsonObject(with: SharedStorage.emptyRules)
        XCTAssertEqual((object as? [Any])?.count, 1)
    }
}
