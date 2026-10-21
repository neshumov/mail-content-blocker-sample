import ContentBlockerConverter
import Foundation
import MailBlockerShared

public struct ConversionSummary {
    public let sourceRules: Int
    public let entries: Int
    public let json: Data
    public let warnings: [String]
}

/// AdGuard rules -> WebKit content-blocking JSON, the format MEContentBlocker returns.
public enum Converter {
    /// WebKit does not load a list longer than this.
    public static let entryLimit = 150_000

    public static func convert(_ text: String) -> ConversionSummary {
        let rules = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("!") }
        var warnings: [String] = []
        guard !rules.isEmpty else {
            return ConversionSummary(sourceRules: 0, entries: 0, json: SharedStorage.emptyRules, warnings: ["No rules: the list blocks nothing."])
        }

        // Advanced blocking (scriptlets, CSS injection) has no meaning in Mail: there is no JavaScript.
        let result = ContentBlockerConverter().convertArray(rules: rules, safariVersion: .safari26, advancedBlocking: false)
        guard result.safariRulesCount > 0, let json = result.safariRulesJSON.data(using: .utf8) else {
            return ConversionSummary(sourceRules: rules.count, entries: 0, json: SharedStorage.emptyRules,
                                     warnings: ["The converter produced no entries: every rule was dropped."])
        }
        if result.safariRulesCount > entryLimit { warnings.append("More than \(entryLimit) entries: WebKit will not load this list.") }
        if result.discardedSafariRules > 0 { warnings.append("\(result.discardedSafariRules) rules were discarded by the converter.") }
        if result.errorsCount > 0 { warnings.append("\(result.errorsCount) rules had errors.") }
        return ConversionSummary(sourceRules: rules.count, entries: result.safariRulesCount, json: json, warnings: warnings)
    }
}
