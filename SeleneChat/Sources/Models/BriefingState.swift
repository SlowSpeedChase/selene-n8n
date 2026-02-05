import Foundation

/// Represents a morning briefing generated for the user
struct Briefing: Equatable {
    /// The briefing content/message
    let content: String

    /// Suggested thread to continue (if any)
    let suggestedThread: String?

    /// Number of active threads
    let threadCount: Int

    /// When the briefing was generated
    let generatedAt: Date
}

/// Loading status for the morning briefing
enum BriefingStatus: Equatable {
    case notLoaded
    case loading
    case loaded(Briefing)
    case failed(String)
}

/// State container for the morning briefing feature
struct BriefingState {
    /// Current loading status of the briefing
    var status: BriefingStatus = .notLoaded
}
