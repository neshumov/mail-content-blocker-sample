import XCTest
@testable import MailBlockerCore

final class RulesFileTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ name: String, _ bytes: [UInt8]) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    func testNoFilesMeansNothingToLoad() {
        XCTAssertNil(RulesFile.load(from: []))
    }

    func testReadsAUTF8File() throws {
        let url = try write("a.txt", Array("||a.example^\n||b.example^\n".utf8))
        XCTAssertEqual(RulesFile.load(from: [url]), .success("||a.example^\n||b.example^\n"))
    }

    func testOnlyTheFirstOfSeveralFilesIsUsed() throws {
        let first = try write("1.txt", Array("first".utf8))
        let second = try write("2.txt", Array("second".utf8))
        XCTAssertEqual(RulesFile.load(from: [first, second]), .success("first"))
    }

    func testByteOrderMarkIsNotGluedToTheFirstRule() throws {
        let url = try write("bom.txt", [0xEF, 0xBB, 0xBF] + Array("||a.example^".utf8))
        guard case .success(let text)? = RulesFile.load(from: [url]) else { return XCTFail("not loaded") }
        XCTAssertEqual(text, "||a.example^")
        XCTAssertEqual(Converter.convert(text).entries, 1, "the first rule must still convert")
    }

    func testLatin1IsReportedNotGuessed() throws {
        let url = try write("latin1.txt", Array("||caf".utf8) + [0xE9] + Array(".example^".utf8))
        XCTAssertEqual(RulesFile.load(from: [url]), .failure(.notUTF8))
    }

    func testMissingFileIsUnreadable() {
        let url = folder.appendingPathComponent("missing.txt")
        XCTAssertEqual(RulesFile.load(from: [url]), .failure(.unreadable))
    }

    func testEmptyFileIsAnEmptyList() throws {
        let url = try write("empty.txt", [])
        XCTAssertEqual(RulesFile.load(from: [url]), .success(""))
    }

    func testWindowsLineEndingsGiveOneRulePerLine() throws {
        let url = try write("crlf.txt", Array("||a.example^\r\n||b.example^\r\n".utf8))
        guard case .success(let text)? = RulesFile.load(from: [url]) else { return XCTFail("not loaded") }
        XCTAssertEqual(Converter.convert(text).sourceRules, 2)
    }

    func testErrorMessagesSayNothingChanged() {
        XCTAssertTrue(RulesFileError.notUTF8.message.contains("nothing changed"))
        XCTAssertTrue(RulesFileError.unreadable.message.contains("nothing changed"))
    }
}
