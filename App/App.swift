import SwiftUI
import MailBlockerCore
import MailBlockerShared

@main
struct MailBlockerApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
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
                    Text("\(current.sourceRules) rules → \(current.entries) entries").font(.headline)
                    ForEach(current.warnings, id: \.self) { Text("⚠︎ \($0)").foregroundStyle(.orange) }
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Mail › Settings › Extensions: turn on “Mail Blocker”.")
                    Text("2. After every change, quit and reopen Mail. Mail applies new rules only at launch.")
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
        .onAppear {
            if SharedStorage.container == nil {
                status = "No App Group: check DEVELOPMENT_TEAM in Local.xcconfig"
            } else {
                summary = Converter.convert(rules)
                log = SharedStorage.readLog()
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

    private func apply() {
        let result = Converter.convert(rules)
        summary = result
        do {
            try SharedStorage.save(json: result.json, source: rules)
            status = "Saved \(result.entries) entries. Restart Mail."
            SharedStorage.log("app: saved \(result.entries) entries")
        } catch {
            status = "Could not save: \(error.localizedDescription)"
        }
        log = SharedStorage.readLog()
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
