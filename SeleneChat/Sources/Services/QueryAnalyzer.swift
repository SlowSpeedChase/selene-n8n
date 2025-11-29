import Foundation

/// Analyzes user queries to determine query type, extract keywords, and infer time scope
class QueryAnalyzer {

    // MARK: - Types

    enum QueryType {
        case pattern      // Trend/pattern detection: "what patterns...", "how often..."
        case search       // Find specific notes: "show me...", "find notes about..."
        case knowledge    // Answer from content: "what did I say...", "remind me..."
        case general      // Open-ended: "how am I doing"
    }

    enum TimeScope {
        case recent       // Last 7 days
        case thisWeek     // Current week
        case thisMonth    // Current month
        case allTime      // No time restriction
        case custom(from: Date, to: Date)
    }

    struct AnalysisResult {
        let queryType: QueryType
        let keywords: [String]
        let timeScope: TimeScope
    }

    // MARK: - Detection Patterns

    private let patternIndicators = [
        "pattern", "trend", "often", "usually", "always", "frequently",
        "when do i", "how often", "what trends", "see patterns"
    ]

    private let searchIndicators = [
        "show", "find", "notes about", "list", "get", "search",
        "display", "where", "which notes"
    ]

    private let knowledgeIndicators = [
        "what did i", "remind me", "what was", "tell me about",
        "what have i", "did i mention", "what do i think"
    ]

    private let stopWords = Set([
        "a", "an", "the", "is", "are", "was", "were", "be", "been",
        "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "can", "and", "or",
        "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "from", "about", "as", "into", "through", "during", "before",
        "after", "above", "below", "between", "under", "i", "me", "my"
    ])

    // MARK: - Public Methods

    func analyze(_ query: String) -> AnalysisResult {
        let lowercased = query.lowercased()

        let queryType = detectQueryType(lowercased)
        let keywords = extractKeywords(from: lowercased)
        let timeScope = detectTimeScope(lowercased)

        return AnalysisResult(
            queryType: queryType,
            keywords: keywords,
            timeScope: timeScope
        )
    }

    // MARK: - Private Detection Methods

    private func detectQueryType(_ query: String) -> QueryType {
        // Check pattern indicators first (most specific)
        for indicator in patternIndicators {
            if query.contains(indicator) {
                return .pattern
            }
        }

        // Check knowledge indicators
        for indicator in knowledgeIndicators {
            if query.contains(indicator) {
                return .knowledge
            }
        }

        // Check search indicators
        for indicator in searchIndicators {
            if query.contains(indicator) {
                return .search
            }
        }

        // Default to general for open-ended questions
        return .general
    }

    private func extractKeywords(from query: String) -> [String] {
        // Split on whitespace and punctuation
        let words = query.components(separatedBy: CharacterSet.alphanumerics.inverted)

        // Filter out stop words and empty strings
        let keywords = words.filter { word in
            !word.isEmpty && !stopWords.contains(word.lowercased())
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return keywords.filter { word in
            if seen.contains(word) {
                return false
            } else {
                seen.insert(word)
                return true
            }
        }
    }

    private func detectTimeScope(_ query: String) -> TimeScope {
        // Check for specific time indicators
        if query.contains("recent") || query.contains("lately") || query.contains("recently") {
            return .recent
        }

        if query.contains("this week") {
            return .thisWeek
        }

        if query.contains("this month") {
            return .thisMonth
        }

        if query.contains("today") {
            return .custom(from: Calendar.current.startOfDay(for: Date()), to: Date())
        }

        if query.contains("yesterday") {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let startOfYesterday = Calendar.current.startOfDay(for: yesterday)
            let endOfYesterday = Calendar.current.date(byAdding: .day, value: 1, to: startOfYesterday)!
            return .custom(from: startOfYesterday, to: endOfYesterday)
        }

        // Default to all time if no time scope specified
        return .allTime
    }
}

// MARK: - CustomStringConvertible

extension QueryAnalyzer.QueryType: CustomStringConvertible {
    var description: String {
        switch self {
        case .pattern: return "pattern"
        case .search: return "search"
        case .knowledge: return "knowledge"
        case .general: return "general"
        }
    }
}

extension QueryAnalyzer.TimeScope: CustomStringConvertible {
    var description: String {
        switch self {
        case .recent: return "recent (last 7 days)"
        case .thisWeek: return "this week"
        case .thisMonth: return "this month"
        case .allTime: return "all time"
        case .custom(let from, let to):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "custom (\(formatter.string(from: from)) - \(formatter.string(from: to)))"
        }
    }
}
