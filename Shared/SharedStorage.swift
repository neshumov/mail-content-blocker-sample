import Foundation
import Security

/// The rules JSON and a small log, shared between the app and the extension through an App Group.
enum SharedStorage {
    /// A valid list that blocks nothing. WebKit refuses an empty array, so this is one harmless rule.
    static let emptyRules = Data(#"[{"trigger":{"url-filter":"^https?://nothing\\.invalid/"},"action":{"type":"ignore-previous-rules"}}]"#.utf8)

    static var container: URL? {
        // macOS group IDs start with the team ID; read the real one from our own entitlement.
        guard let id = groupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static var groupID: String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String]
        else { return nil }
        return groups.first
    }

    static var rulesURL: URL? { container?.appendingPathComponent("rules.json") }
    static var sourceURL: URL? { container?.appendingPathComponent("rules.txt") }
    static var logURL: URL? { container?.appendingPathComponent("blocker.log") }

    static func save(json: Data, source: String) throws {
        guard let rules = rulesURL, let src = sourceURL else { throw CocoaError(.fileNoSuchFile) }
        try json.write(to: rules, options: .atomic)
        try Data(source.utf8).write(to: src, options: .atomic)
    }

    static func loadRules() -> Data? { rulesURL.flatMap { try? Data(contentsOf: $0) } }
    static func loadSource() -> String? { sourceURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } }

    static func log(_ message: String) {
        guard let url = logURL else { return }
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    static func readLog() -> String { logURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "" }
}
