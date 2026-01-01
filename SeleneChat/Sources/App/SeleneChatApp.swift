import SwiftUI
import AppKit

@main
struct SeleneChatApp: App {
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var compressionService = CompressionService(databaseService: DatabaseService.shared)

    init() {
        // Activate the app so it appears in the foreground
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        #if DEBUG
        setupDebugSystem()
        #endif
    }

    #if DEBUG
    private func setupDebugSystem() {
        DebugLogger.shared.log(.state, "App launched")

        // Register snapshot providers
        DebugSnapshotService.shared.registerProvider(named: "actions", provider: ActionTracker.shared)

        // Start watching for snapshot requests
        DebugSnapshotService.shared.startWatching()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseService)
                .environmentObject(chatViewModel)
                .frame(minWidth: 800, minHeight: 600)
                .task {
                    // Run compression check asynchronously on launch
                    await compressionService.checkAndCompressSessions()
                }
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
