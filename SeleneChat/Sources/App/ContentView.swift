import SwiftUI

struct ContentView: View {
    @State private var selectedView: NavigationItem = .chat
    @EnvironmentObject var databaseService: DatabaseService

    enum NavigationItem: String, CaseIterable {
        case chat = "Chat"
        case search = "Search"

        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .search: return "magnifyingglass"
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
            case .chat:
                ChatView()
            case .search:
                SearchView()
            }
        }
    }
}
