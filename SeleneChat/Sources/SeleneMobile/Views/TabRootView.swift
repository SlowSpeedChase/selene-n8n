import SwiftUI
import SeleneShared

struct TabRootView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        TabView {
            if let dp = connectionManager.dataProvider, let llm = connectionManager.llmProvider {
                MobileChatView(dataProvider: dp, llmProvider: llm)
                    .tabItem { Label("Chat", systemImage: "message") }
            } else {
                Text("Connecting...")
                    .tabItem { Label("Chat", systemImage: "message") }
            }

            Text("Threads -- Coming Soon")
                .tabItem { Label("Threads", systemImage: "circle.hexagongrid") }
            Text("Briefing -- Coming Soon")
                .tabItem { Label("Briefing", systemImage: "sun.max") }
            MobileSettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
