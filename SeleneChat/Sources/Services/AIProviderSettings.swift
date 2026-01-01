// SeleneChat/Sources/Services/AIProviderSettings.swift
import Foundation
import SwiftUI

enum AIProvider: String, CaseIterable {
    case ollama = "ollama"
    case claude = "claude"

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (Local)"
        case .claude: return "Claude API"
        }
    }

    var icon: String {
        switch self {
        case .ollama: return "desktopcomputer"
        case .claude: return "cloud"
        }
    }

    var description: String {
        switch self {
        case .ollama: return "Private, runs on your Mac. Best for sensitive content."
        case .claude: return "Cloud AI, better reasoning. No personal data sent."
        }
    }

    var privacyBadge: String {
        switch self {
        case .ollama: return "🔒 Local"
        case .claude: return "🌐 Cloud"
        }
    }
}

class AIProviderSettings: ObservableObject {
    static let shared = AIProviderSettings()

    private let defaultProviderKey = "defaultAIProvider"

    @Published var defaultProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(defaultProvider.rawValue, forKey: defaultProviderKey)
        }
    }

    init() {
        if let savedValue = UserDefaults.standard.string(forKey: defaultProviderKey),
           let provider = AIProvider(rawValue: savedValue) {
            self.defaultProvider = provider
        } else {
            // Default to Ollama (local)
            self.defaultProvider = .ollama
        }
    }
}
