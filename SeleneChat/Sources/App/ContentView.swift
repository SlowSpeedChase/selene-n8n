import SwiftUI

struct ContentView: View {
    @State private var selectedView: NavigationItem = .today
    @State private var pendingThreadQuery: String?
    @State private var showBriefing = true  // Show briefing on app open
    @State private var selectedThreadId: Int64?  // For thread workspace navigation
    @EnvironmentObject var databaseService: DatabaseService

    enum NavigationItem: String, CaseIterable {
        case today = "Today"
        case chat = "Chat"
        case search = "Search"
        case planning = "Planning"

        var icon: String {
            switch self {
            case .today: return "sun.horizon.fill"
            case .chat: return "message.fill"
            case .search: return "magnifyingglass"
            case .planning: return "list.bullet.clipboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, id: \.self, selection: $selectedView) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Selene")
            .frame(minWidth: 200)
        } detail: {
            if let threadId = selectedThreadId {
                // Thread Workspace view
                ThreadWorkspaceView(threadId: threadId)
                    .environmentObject(databaseService)
                    .onDisappear {
                        // Clear when navigating away (though sheet dismissal handles this too)
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: { selectedThreadId = nil }) {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            } else if showBriefing {
                BriefingView(
                    onDismiss: {
                        showBriefing = false
                    },
                    onDigIn: { query in
                        showBriefing = false
                        pendingThreadQuery = query
                        selectedView = .chat
                    }
                )
            } else {
                switch selectedView {
                case .today:
                    TodayView(
                        onThreadSelected: { thread in
                            // Navigate to Thread Workspace
                            selectedThreadId = thread.id
                        },
                        onNoteThreadTap: { note in
                            if let threadId = note.threadId {
                                // Navigate to Thread Workspace
                                selectedThreadId = threadId
                            }
                        }
                    )
                case .chat:
                    ChatView(initialQuery: pendingThreadQuery)
                        .onAppear { pendingThreadQuery = nil }
                case .search:
                    SearchView()
                case .planning:
                    PlanningView()
                }
            }
        }
        .onAppear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Appeared: ContentView")
            ActionTracker.shared.track(action: "viewAppeared", params: ["view": "ContentView"])
            #endif
        }
        .onDisappear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Disappeared: ContentView")
            #endif
        }
    }
}
