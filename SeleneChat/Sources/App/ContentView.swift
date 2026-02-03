import SwiftUI

struct ContentView: View {
    @State private var selectedView: NavigationItem = .today
    @State private var pendingThreadQuery: String?
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
            switch selectedView {
            case .today:
                TodayView(
                    onThreadSelected: { thread in
                        pendingThreadQuery = "show me \(thread.name) thread"
                        selectedView = .chat
                    },
                    onNoteThreadTap: { note in
                        if let threadName = note.threadName {
                            pendingThreadQuery = "What's happening with \(threadName)?"
                            selectedView = .chat
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
