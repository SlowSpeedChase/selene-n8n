import SwiftUI

struct MobileSettingsView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    LabeledContent("Server", value: connectionManager.serverURL)
                    LabeledContent("Status", value: connectionManager.isConnected ? "Connected" : "Disconnected")
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
