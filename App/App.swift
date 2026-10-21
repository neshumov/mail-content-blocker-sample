import MailKit
import SwiftUI
import MailBlockerCore
import MailBlockerShared

/// A file handed to the app (Finder, `open -a "Mail Blocker" list.txt`, drag onto the Dock icon).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let result = RulesFile.load(from: urls) else { return }
        OpenedRulesInbox.shared.deliver(result)
    }
}

@main
struct MailBlockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var delegate

    var body: some Scene {
        // One window only: a WindowGroup would open a new window for every file handed to the app.
        Window("Mail Blocker", id: "main") { ContentView() }
            .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @State private var rules = SharedStorage.loadSource() ?? """
    ! One AdGuard rule per line; lines starting with ! are comments.
    ||pixel.example.com^$image
    ||track.example.net/open.gif?
    /beacon/*.gif$image
    """
    @State private var summary: ConversionSummary?
    @State private var status = ""
    @State private var showJSON = false
    @State private var showLog = false
    @State private var log = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mail Blocker").font(.title2.bold())
            Text("Converts AdGuard rules to WebKit JSON and hands them to Mail through the extension.")
                .foregroundStyle(.secondary)

            TextEditor(text: $rules)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 180)

            HStack {
                Button("Convert and save") { apply() }.keyboardShortcut(.return, modifiers: .command)
                Button("Quit and reopen Mail") { restartMail() }
                Spacer()
                Text(status).foregroundStyle(.secondary)
            }

            if let current = summary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.headline).font(.headline)
                    ForEach(current.warnings, id: \.self) { Text("⚠︎ \($0)").foregroundStyle(.orange) }
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Mail › Settings › Extensions: turn on “Mail Blocker”.")
                    Text("2. Convert and save asks Mail to reload the rules.")
                    Text("If a change does not show, quit and reopen Mail.")
                    Text("There is no API that tells you the extension is on, or what it blocked.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DisclosureGroup("JSON sent to Mail", isExpanded: $showJSON) {
                ScrollView {
                    Text(prettyJSON)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 120)
            }
            DisclosureGroup("Extension log", isExpanded: $showLog) {
                VStack(alignment: .leading, spacing: 6) {
                    Button("Refresh") { log = SharedStorage.readLog() }.controlSize(.small)
                    ScrollView {
                        Text(log.isEmpty ? "empty: Mail has not asked the extension yet" : log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 80)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 640)
        .onReceive(NotificationCenter.default.publisher(for: OpenedRulesInbox.didArrive)) { _ in useOpenedRules() }
        .onAppear {
            if SharedStorage.container == nil {
                status = "No App Group: check DEVELOPMENT_TEAM in Local.xcconfig"
            } else {
                summary = Converter.convert(rules)
                log = SharedStorage.readLog()
                useOpenedRules()
            }
        }
    }

    private var prettyJSON: String {
        guard let data = SharedStorage.loadRules(),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: pretty, encoding: .utf8) else { return "nothing saved yet" }
        return text
    }

    /// A file opened from outside replaces the editor text and is applied at once.
    private func useOpenedRules() {
        switch OpenedRulesInbox.shared.take() {
        case .none:
            return
        case .success(let text):
            rules = text
            apply()
        case .failure(let error):
            status = error.message
        }
    }

    private func apply() {
        let outcome = RulesApplier.apply(rules)
        summary = outcome.summary
        status = outcome.status
        log = SharedStorage.readLog()
        askMailToReload()
    }

    /// Mail keeps the rules it already has for a message that is open; this asks it to read them again.
    /// The answer only says the request was accepted: nothing tells us whether Mail did it or when.
    private func askMailToReload() {
        guard let id = Bundle.main.bundleIdentifier.map({ $0 + ".extension" }) else { return }
        MEExtensionManager.reloadContentBlocker(withIdentifier: id) { error in
            DispatchQueue.main.async {
                let answer = error.map { "error: \($0.localizedDescription)" } ?? "accepted"
                SharedStorage.log("app: reloadContentBlocker -> \(answer)")
                log = SharedStorage.readLog()
            }
        }
    }

    private func restartMail() {
        let mail = "com.apple.mail"
        NSRunningApplication.runningApplications(withBundleIdentifier: mail).forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mail) else { return }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
