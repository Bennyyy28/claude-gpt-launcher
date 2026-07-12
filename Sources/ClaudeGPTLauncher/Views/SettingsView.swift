import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("Backend launcher") {
                Text("~/.local/bin/claude-gpt")
                    .font(.body.monospaced())
            }
            LabeledContent("Proxy address") {
                Text("127.0.0.1:18765")
                    .font(.body.monospaced())
            }
            Text("Authentication is stored by claude-code-proxy in macOS Keychain. This is a third-party routing configuration, not an officially supported OpenAI client setup.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
    }
}
