import SwiftUI
import SeleneShared

@main
struct SeleneMobileApp: App {
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            if connectionManager.isConfigured {
                TabRootView()
                    .environmentObject(connectionManager)
            } else {
                ServerSetupView()
                    .environmentObject(connectionManager)
            }
        }
    }
}
