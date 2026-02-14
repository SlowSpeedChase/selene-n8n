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

    init() {
        loadSaved()
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
            save()
            return true
        }
        return false
    }

    private func loadSaved() {
        if let url = UserDefaults.standard.string(forKey: "selene_server_url"),
           let token = UserDefaults.standard.string(forKey: "selene_api_token"),
           !url.isEmpty {
            self.serverURL = url
            self.apiToken = token
            self.isConfigured = true
            Task {
                _ = await configure(serverURL: url, apiToken: token)
            }
        }
    }

    private func save() {
        UserDefaults.standard.set(serverURL, forKey: "selene_server_url")
        UserDefaults.standard.set(apiToken, forKey: "selene_api_token")
    }
}
