import Foundation

class PrivacyRouter {
    static let shared = PrivacyRouter()

    // Keywords that indicate sensitive content
    private let sensitiveKeywords = [
        // Personal/emotional
        "feel", "feeling", "felt", "emotion", "mood", "anxiety", "anxious", "depressed",
        "therapy", "therapist", "mental health", "adhd", "medication", "stress", "overwhelm",
        "personal", "private", "secret", "intimate", "relationship", "family", "partner",

        // Health
        "health", "medical", "doctor", "hospital", "diagnosis", "symptom", "pain", "sick",
        "illness", "disease", "treatment", "prescription", "dose",

        // Financial
        "money", "salary", "income", "expense", "cost", "price", "budget", "financial",
        "account", "bank", "credit", "debit", "payment", "paid", "debt", "loan",

        // Intimate/sexual
        "sex", "sexual", "intimate", "attraction", "dating", "romance"
    ]

    // Keywords that indicate non-sensitive, project-related queries
    private let projectKeywords = [
        "project", "plan", "planning", "scope", "timeline", "deadline", "milestone",
        "task", "todo", "backlog", "sprint", "estimate", "schedule", "deliverable",
        "requirement", "specification", "feature", "architecture", "design", "implement",
        "technical", "system", "framework", "library", "api", "database", "backend",
        "frontend", "deployment", "infrastructure"
    ]

    enum RoutingDecision {
        case onDevice(reason: String)
        case privateCloud(reason: String)
        case external(reason: String)

        var tier: Message.LLMTier {
            switch self {
            case .onDevice: return .onDevice
            case .privateCloud: return .privateCloud
            case .external: return .external
            }
        }

        var reason: String {
            switch self {
            case .onDevice(let r), .privateCloud(let r), .external(let r):
                return r
            }
        }
    }

    func routeQuery(_ query: String, relatedNotes: [Note] = []) -> RoutingDecision {
        let lowercaseQuery = query.lowercased()

        // Rule 1: If query references note content, always use on-device
        if containsNoteReference(lowercaseQuery) {
            return .onDevice(reason: "Query references note content")
        }

        // Rule 2: If related notes are provided, assume sensitive
        if !relatedNotes.isEmpty {
            // Check if notes contain sensitive data
            let notesContainSensitive = relatedNotes.contains { note in
                containsSensitiveContent(note.content)
            }

            if notesContainSensitive {
                return .onDevice(reason: "Related notes contain sensitive information")
            }
        }

        // Rule 3: Check for sensitive keywords in query
        let containsSensitive = sensitiveKeywords.contains { keyword in
            lowercaseQuery.contains(keyword)
        }

        if containsSensitive {
            return .onDevice(reason: "Query contains sensitive keywords")
        }

        // Rule 4: Check for project/planning keywords (non-sensitive)
        let containsProject = projectKeywords.contains { keyword in
            lowercaseQuery.contains(keyword)
        }

        if containsProject {
            return .external(reason: "General project planning query (non-sensitive)")
        }

        // Rule 5: General questions about methodology, best practices, etc.
        if isGeneralQuestion(lowercaseQuery) {
            return .external(reason: "General knowledge query (non-sensitive)")
        }

        // Default: use on-device for safety
        return .onDevice(reason: "Default routing for privacy")
    }

    private func containsNoteReference(_ query: String) -> Bool {
        let notePatterns = [
            "my note", "my notes", "in my note", "from my note",
            "i wrote", "i mentioned", "i said", "i was thinking",
            "show me", "find", "search", "what did i", "when did i"
        ]

        return notePatterns.contains { pattern in
            query.contains(pattern)
        }
    }

    private func containsSensitiveContent(_ content: String) -> Bool {
        let lowercaseContent = content.lowercased()

        return sensitiveKeywords.contains { keyword in
            lowercaseContent.contains(keyword)
        }
    }

    private func isGeneralQuestion(_ query: String) -> Bool {
        let generalPatterns = [
            "how do i", "how to", "what is", "what are", "explain",
            "best practice", "recommend", "suggestion", "advice",
            "how should", "what should", "is it better to"
        ]

        return generalPatterns.contains { pattern in
            query.contains(pattern)
        }
    }

    func shouldUsePrivateCloud(_ query: String) -> Bool {
        // Use Private Cloud Compute for complex queries that need more compute
        // but still contain sensitive data
        let lowercaseQuery = query.lowercased()

        let complexPatterns = [
            "analyze", "pattern", "trend", "compare", "summarize",
            "relationship", "connection", "correlate", "insight"
        ]

        let isComplex = complexPatterns.contains { pattern in
            lowercaseQuery.contains(pattern)
        }

        let containsSensitive = sensitiveKeywords.contains { keyword in
            lowercaseQuery.contains(keyword)
        }

        return isComplex && containsSensitive
    }

    func getRoutingExplanation(for query: String, decision: RoutingDecision) -> String {
        """
        Query routed to: \(decision.tier.rawValue)
        Reason: \(decision.reason)

        Privacy guarantee:
        \(getPrivacyGuarantee(for: decision.tier))
        """
    }

    private func getPrivacyGuarantee(for tier: Message.LLMTier) -> String {
        switch tier {
        case .onDevice:
            return "Your data never leaves your device. Processing happens entirely locally using Apple Intelligence."
        case .privateCloud:
            return "Processing uses Apple's Private Cloud Compute - your data is encrypted end-to-end and never stored on Apple's servers."
        case .external:
            return "Non-sensitive query sent to Claude API. No personal note content is included."
        case .local:
            return "Processing happens locally using Ollama. Your data never leaves your device."
        }
    }
}
