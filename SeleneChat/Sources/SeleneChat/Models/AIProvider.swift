// SeleneChat/Sources/Models/AIProvider.swift
import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case local   // Ollama
    case cloud   // Claude API

    var displayName: String {
        switch self {
        case .local: return "Local"
        case .cloud: return "Cloud"
        }
    }

    var icon: String {
        switch self {
        case .local: return "🏠"
        case .cloud: return "☁️"
        }
    }

    var systemImage: String {
        switch self {
        case .local: return "house.fill"
        case .cloud: return "cloud.fill"
        }
    }
}
