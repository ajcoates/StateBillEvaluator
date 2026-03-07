import SwiftUI

struct SettingsView: View {
    @AppStorage("legiScanAPIKey") private var legiScanAPIKey: String = ""
    @AppStorage("claudeAPIKey") private var claudeAPIKey: String = ""

    var body: some View {
        Form {
            Section {
                SecureField("LegiScan API Key", text: $legiScanAPIKey)
                    .textFieldStyle(.roundedBorder)
                Text("Get a free API key at legiscan.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("LegiScan API")
            }

            Section {
                SecureField("Claude API Key", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)
                Text("Used for automatic bill categorization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Claude API")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 250)
        .navigationTitle("Settings")
    }
}
