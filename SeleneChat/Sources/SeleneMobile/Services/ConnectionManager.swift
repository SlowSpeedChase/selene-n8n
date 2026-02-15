import Foundation
import SeleneShared
import SwiftUI

@MainActor
class ConnectionManager: ObservableObject {
    @Published var serverURL: String = ""
    @Published var apiToken: String = ""
    @Published var isConnected = false
    @Published var isConfigured = false

    private(set) var dataProvider: RemoteDataService?
    private(set) var llmProvider: RemoteOllamaService?

    private static let defaultServerURL = "http://100.111.6.10:5678"

    init() {
        self.serverURL = Self.defaultServerURL
        self.apiToken = ""
        self.isConfigured = true
        Task {
            _ = await configure(serverURL: Self.defaultServerURL, apiToken: "")
        }
    }

    func configure(serverURL: String, apiToken: String) async -> Bool {
        self.serverURL = serverURL
        self.apiToken = apiToken

        let remote = RemoteDataService(baseURL: serverURL, token: apiToken)
        let remoteLLM = RemoteOllamaService(baseURL: serverURL, token: apiToken)

        let available = await remote.isAPIAvailable()
        if available {
            self.dataProvider = remote
            self.llmProvider = remoteLLM
            self.isConnected = true
            self.isConfigured = true
            return true
        }
        return false
    }

    private func save() {
        UserDefaults.standard.set(serverURL, forKey: "selene_server_url")
        UserDefaults.standard.set(apiToken, forKey: "selene_api_token")
    }
}
