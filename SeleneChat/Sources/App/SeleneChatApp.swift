import SwiftUI
import AppKit

@main
struct SeleneChatApp: App {
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var compressionService = CompressionService(databaseService: DatabaseService.shared)
    @StateObject private var speechService = SpeechRecognitionService()

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

        // Configure ThingsURLService with DatabaseService for task_links recording
        ThingsURLService.shared.configure(with: DatabaseService.shared)
    }

    #if DEBUG
    private func setupDebugSystem() {
        DebugLogger.shared.log(.state, "App launched")

        // Register snapshot providers
        DebugSnapshotService.shared.registerProvider(named: "actions", provider: ActionTracker.shared)

        // Note: chatViewModel registration moved to .task modifier in body
        // because ChatViewModel is @MainActor isolated

        // Start watching for snapshot requests
        DebugSnapshotService.shared.startWatching()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseService)
                .environmentObject(chatViewModel)
                .environmentObject(speechService)
                .frame(minWidth: 800, minHeight: 600)
                .task {
                    // Run compression check asynchronously on launch
                    await compressionService.checkAndCompressSessions()

                    #if DEBUG
                    // Register chatViewModel provider on main actor
                    await MainActor.run {
                        DebugSnapshotService.shared.registerProvider(named: "chatViewModel", provider: chatViewModel)
                    }
                    #endif
                }
                .onOpenURL { url in
                    let action = VoiceInputManager.parseURL(url)
                    if action == .activateVoice {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        Task {
                            try? await Task.sleep(for: .milliseconds(200))
                            await speechService.startListening()
                        }
                    }
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
