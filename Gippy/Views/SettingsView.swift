import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tenor API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                SecureField("Paste your API key here", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Link(
                    "Get a free key → Google Cloud Console",
                    destination: URL(string: "https://console.cloud.google.com/apis/library/tenor.googleapis.com")!
                )
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Global Hotkey")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("⌥G  (Option + G) — works from any app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if saved {
                Label("Saved!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            apiKey = Keychain.read(key: "tenorAPIKey") ?? ""
        }
    }

    private func save() {
        Keychain.write(key: "tenorAPIKey", value: apiKey)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
    }
}
