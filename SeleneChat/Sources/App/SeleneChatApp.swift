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

        // Configure services with database connection
        configureServices()

        #if DEBUG
        setupDebugSystem()
        #endif
    }

    private func configureServices() {
        // Configure InboxService and ProjectService with database connection
        // These services need the db connection to query inbox notes and projects
        if let db = DatabaseService.shared.db {
            InboxService.shared.configure(with: db)
            ProjectService.shared.configure(with: db)
        }
    }

    #if DEBUG
    private func setupDebugSystem() {
        DebugLogger.shared.log(.state, "App launched")

        // Register snapshot providers
        DebugSnapshotService.shared.registerProvider(named: "actions", provider: ActionTracker.shared)
        DebugSnapshotService.shared.registerProvider(named: "chatViewModel", provider: chatViewModel)

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
