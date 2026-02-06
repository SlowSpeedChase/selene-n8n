import Foundation

/// Query types for Thinking Partner modes
enum ThinkingPartnerQueryType: String {
    case briefing   // Morning briefing - threads + momentum
    case synthesis  // Cross-thread prioritization
    case deepDive   // Single thread exploration

    /// Token budget for context assembly
    var tokenBudget: Int {
        switch self {
        case .briefing: return 1500
        case .synthesis: return 2000
        case .deepDive: return 3000
        }
    }

    /// Description for debugging
    var description: String {
        switch self {
        case .briefing: return "Morning Briefing"
        case .synthesis: return "Cross-Thread Synthesis"
        case .deepDive: return "Thread Deep-Dive"
        }
    }
}
