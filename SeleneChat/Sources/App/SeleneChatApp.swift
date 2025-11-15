import SwiftUI
import AppKit

@main
struct SeleneChatApp: App {
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var chatViewModel = ChatViewModel()

    init() {
        // Activate the app so it appears in the foreground
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseService)
                .environmentObject(chatViewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(databaseService)
        }
    }
}
