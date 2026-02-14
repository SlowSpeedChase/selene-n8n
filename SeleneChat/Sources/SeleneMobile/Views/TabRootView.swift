import SwiftUI
import SeleneShared

struct TabRootView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        TabView {
            Text("Chat -- Coming Soon")
                .tabItem { Label("Chat", systemImage: "message") }
            Text("Threads -- Coming Soon")
                .tabItem { Label("Threads", systemImage: "circle.hexagongrid") }
            Text("Briefing -- Coming Soon")
                .tabItem { Label("Briefing", systemImage: "sun.max") }
            MobileSettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
