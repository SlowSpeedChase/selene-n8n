import SwiftUI

struct ContentView: View {
    @State private var selectedView: NavigationItem = .chat
    @EnvironmentObject var databaseService: DatabaseService
    @ObservedObject private var connectionSettings = ConnectionSettings.shared
    @ObservedObject private var dataServiceManager = DataServiceManager.shared

    enum NavigationItem: String, CaseIterable {
        case chat = "Chat"
        case search = "Search"
        case planning = "Planning"

        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .search: return "magnifyingglass"
            case .planning: return "list.bullet.clipboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(NavigationItem.allCases, id: \.self, selection: $selectedView) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
                .navigationTitle("Selene")

                Divider()

                // Connection status indicator
                connectionStatusView
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(minWidth: 200)
        } detail: {
            switch selectedView {
            case .chat:
                ChatView()
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

    private var connectionStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Connection status dot
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 8, height: 8)

                // Mode label
                Text(connectionSettings.connectionMode == .local ? "Local" : "Remote")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()

                // Mode icon
                Image(systemName: connectionSettings.connectionMode == .local ? "laptopcomputer" : "network")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if connectionSettings.connectionMode == .remote && !connectionSettings.serverAddress.isEmpty {
                Text(connectionSettings.serverAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if let error = dataServiceManager.connectionError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
    }

    private var connectionStatusColor: Color {
        if connectionSettings.connectionMode == .local {
            return databaseService.isConnected ? .green : .red
        } else {
            return dataServiceManager.isConnected ? .green : .orange
        }
    }
}
