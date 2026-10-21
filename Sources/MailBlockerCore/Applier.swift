import Foundation
import MailBlockerShared

public struct ApplyOutcome {
    public let summary: ConversionSummary
    public let status: String
}

/// Converts a list, saves it for the extension and says what happened.
public enum RulesApplier {
    public static func apply(_ text: String) -> ApplyOutcome {
        let summary = Converter.convert(text)
        let status: String
        do {
            try SharedStorage.save(json: summary.json, source: text)
            SharedStorage.log("app: saved \(summary.entries) entries")
            status = "Saved \(Wording.count(summary.entries, "entry", "entries"))."
        } catch {
            status = "Could not save: \(error.localizedDescription)"
        }
        return ApplyOutcome(summary: summary, status: status)
    }
}

public enum Wording {
    public static func count(_ number: Int, _ one: String, _ many: String) -> String {
        "\(number) \(number == 1 ? one : many)"
    }
}

public extension ConversionSummary {
    /// "3 rules → 3 entries"
    var headline: String {
        "\(Wording.count(sourceRules, "rule", "rules")) → \(Wording.count(entries, "entry", "entries"))"
    }
}
