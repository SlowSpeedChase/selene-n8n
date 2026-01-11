import Foundation

/// Manages connection settings for switching between local and remote data sources.
class ConnectionSettings: ObservableObject {
    static let shared = ConnectionSettings()

    enum ConnectionMode: String, CaseIterable {
        case local = "local"
        case remote = "remote"
    }

    @Published var connectionMode: ConnectionMode {
        didSet {
            UserDefaults.standard.set(connectionMode.rawValue, forKey: "connectionMode")
        }
    }

    @Published var serverAddress: String {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: "serverAddress")
        }
    }

    init() {
        // Load saved values from UserDefaults
        if let savedMode = UserDefaults.standard.string(forKey: "connectionMode"),
           let mode = ConnectionMode(rawValue: savedMode) {
            self.connectionMode = mode
        } else {
            self.connectionMode = .local
        }

        self.serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
    }

    /// Returns true if we should use remote API service
    var isRemote: Bool {
        connectionMode == .remote && !serverAddress.isEmpty
    }

    /// Full base URL for API calls
    var apiBaseURL: URL? {
        guard isRemote else { return nil }
        return URL(string: "http://\(serverAddress):5678")
    }

    /// Ollama URL - local or remote based on connection mode
    var ollamaURL: String {
        if isRemote {
            return "http://\(serverAddress):11434"
        } else {
            return "http://localhost:11434"
        }
    }
}
