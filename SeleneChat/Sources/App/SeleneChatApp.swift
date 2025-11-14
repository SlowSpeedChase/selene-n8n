import SwiftUI
import AppKit

@main
struct SeleneChatApp: App {
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var chatViewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseService)
                .environmentObject(chatViewModel)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Activate the app and bring window to front when it appears
                    // MUST use async dispatch - activation doesn't work during onAppear
                    DispatchQueue.main.async {
                        print("🔍 DEBUG: Activating app (async)")
                        print("🔍 DEBUG: NSApp.isActive before: \(NSApp.isActive)")
                        NSApp.activate(ignoringOtherApps: true)

                        // Small delay to ensure activation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            print("🔍 DEBUG: NSApp.isActive after delay: \(NSApp.isActive)")

                            // Make the main window key and front
                            print("🔍 DEBUG: Number of windows: \(NSApp.windows.count)")
                            if let window = NSApp.windows.first {
                                print("🔍 DEBUG: Window isKeyWindow before: \(window.isKeyWindow)")
                                print("🔍 DEBUG: Window canBecomeKey: \(window.canBecomeKey)")
                                window.makeKeyAndOrderFront(nil)

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    print("🔍 DEBUG: Window isKeyWindow after: \(window.isKeyWindow)")
                                    print("🔍 DEBUG: Window isMainWindow: \(window.isMainWindow)")
                                }
                            }
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
