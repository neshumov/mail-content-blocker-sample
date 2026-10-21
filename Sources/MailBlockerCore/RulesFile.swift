import Foundation

public enum RulesFileError: Error, Equatable {
    case unreadable
    case notUTF8

    public var message: String {
        switch self {
        case .unreadable: return "Could not read the file; nothing changed."
        case .notUTF8: return "Could not read the file as UTF-8 text; nothing changed."
        }
    }
}

/// Reads a list of rules that was handed to the app from outside.
public enum RulesFile {
    /// Loads the first of the given files. Returns nil when there is nothing to load.
    public static func load(from urls: [URL]) -> Result<String, RulesFileError>? {
        guard let url = urls.first else { return nil }
        guard let data = try? Data(contentsOf: url) else { return .failure(.unreadable) }
        // Decoding drops a UTF-8 byte order mark, so it cannot glue itself to the first rule.
        guard let text = String(data: data, encoding: .utf8) else { return .failure(.notUTF8) }
        return .success(text)
    }
}

/// Holds a file that arrived before the window was ready, and tells the window when one arrives later.
public final class OpenedRulesInbox {
    public static let didArrive = Notification.Name("MailBlocker.openedRules")
    public static let shared = OpenedRulesInbox()

    private var pending: Result<String, RulesFileError>?
    private let center: NotificationCenter

    public init(center: NotificationCenter = .default) {
        self.center = center
    }

    public func deliver(_ result: Result<String, RulesFileError>) {
        pending = result
        center.post(name: Self.didArrive, object: self)
    }

    /// Returns what is waiting, once.
    public func take() -> Result<String, RulesFileError>? {
        defer { pending = nil }
        return pending
    }
}
