import Foundation
import Security

/// The rules JSON and a small log, shared between the app and the extension through an App Group.
public enum SharedStorage {
    /// A valid list that blocks nothing. WebKit refuses an empty array, so this is one harmless rule.
    public static let emptyRules = Data(
        #"[{"trigger":{"url-filter":"^https?://nothing\\.invalid/"},"action":{"type":"ignore-previous-rules"}}]"#.utf8
    )

    public static var container: URL? {
        // macOS group IDs start with the team ID; read the real one from our entitlement.
        guard let id = groupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    public static var groupID: String? {
        let key = "com.apple.security.application-groups" as CFString
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, key, nil) as? [String]
        else { return nil }
        return groups.first
    }

    public static var rulesURL: URL? { container?.appendingPathComponent("rules.json") }
    public static var sourceURL: URL? { container?.appendingPathComponent("rules.txt") }
    public static var logURL: URL? { container?.appendingPathComponent("blocker.log") }

    public static func save(json: Data, source: String) throws {
        guard let rules = rulesURL, let src = sourceURL else { throw CocoaError(.fileNoSuchFile) }
        try json.write(to: rules, options: .atomic)
        try Data(source.utf8).write(to: src, options: .atomic)
    }

    public static func loadRules() -> Data? { rulesURL.flatMap { try? Data(contentsOf: $0) } }
    public static func loadSource() -> String? { sourceURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } }

    public static func log(_ message: String) {
        guard let url = logURL else { return }
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    public static func readLog() -> String { logURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "" }
}
