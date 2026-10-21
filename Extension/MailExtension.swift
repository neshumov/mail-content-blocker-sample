import MailKit
import MailBlockerShared

/// Mail instantiates this class (NSExtensionPrincipalClass in Info.plist).
final class MailExtension: NSObject, MEExtension {
    func handlerForContentBlocker() -> MEContentBlocker { ContentBlocker() }
}

/// Hands Mail the WebKit content-blocking JSON the container app has prepared.
/// There is no callback for what Mail does with it: no counter, no status.
final class ContentBlocker: NSObject, MEContentBlocker {
    func contentRulesJSON() -> Data {
        let json = SharedStorage.loadRules() ?? SharedStorage.emptyRules
        SharedStorage.log("contentRulesJSON() -> \(json.count) bytes")
        return json
    }
}
