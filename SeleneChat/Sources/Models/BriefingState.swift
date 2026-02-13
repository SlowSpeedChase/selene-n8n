import Foundation

/// Types of briefing cards
enum BriefingCardType: Equatable {
    case whatChanged
    case needsAttention
    case connection
}

/// A single briefing card with data for one insight
struct BriefingCard: Identifiable, Equatable {
    let id = UUID()
    let cardType: BriefingCardType

    // What Changed fields
    var noteTitle: String?
    var noteId: Int?
    var threadName: String?
    var threadId: Int64?
    var date: Date?
    var primaryTheme: String?
    var energyLevel: String?

    // Needs Attention fields
    var reason: String?
    var noteCount: Int?
    var openTaskCount: Int?

    // Connection fields
    var noteATitle: String?
    var noteAId: Int?
    var threadAName: String?
    var noteBTitle: String?
    var noteBId: Int?
    var threadBName: String?
    var explanation: String?

    // Preview content (loaded on expand)
    var notePreview: String?
    var threadSummary: String?
    var threadWhy: String?

    var energyEmoji: String {
        switch energyLevel?.lowercased() {
        case "high": return "\u{26A1}"
        case "medium": return "\u{1F50B}"
        case "low": return "\u{1FAAB}"
        default: return ""
        }
    }

    // MARK: - Factory Methods

    static func whatChanged(
        noteTitle: String,
        noteId: Int,
        threadName: String?,
        threadId: Int64?,
        date: Date,
        primaryTheme: String?,
        energyLevel: String?
    ) -> BriefingCard {
        BriefingCard(
            cardType: .whatChanged,
            noteTitle: noteTitle,
            noteId: noteId,
            threadName: threadName,
            threadId: threadId,
            date: date,
            primaryTheme: primaryTheme,
            energyLevel: energyLevel
        )
    }

    static func needsAttention(
        threadName: String,
        threadId: Int64,
        reason: String,
        noteCount: Int,
        openTaskCount: Int
    ) -> BriefingCard {
        BriefingCard(
            cardType: .needsAttention,
            threadName: threadName,
            threadId: threadId,
            reason: reason,
            noteCount: noteCount,
            openTaskCount: openTaskCount
        )
    }

    static func connection(
        noteATitle: String,
        noteAId: Int,
        threadAName: String,
        noteBTitle: String,
        noteBId: Int,
        threadBName: String,
        explanation: String
    ) -> BriefingCard {
        BriefingCard(
            cardType: .connection,
            noteATitle: noteATitle,
            noteAId: noteAId,
            threadAName: threadAName,
            noteBTitle: noteBTitle,
            noteBId: noteBId,
            threadBName: threadBName,
            explanation: explanation
        )
    }

    // Equatable (ignore UUID id)
    static func == (lhs: BriefingCard, rhs: BriefingCard) -> Bool {
        lhs.cardType == rhs.cardType &&
        lhs.noteTitle == rhs.noteTitle &&
        lhs.noteId == rhs.noteId &&
        lhs.threadName == rhs.threadName
    }
}

/// Structured briefing with sections
struct StructuredBriefing: Equatable {
    let intro: String
    let whatChanged: [BriefingCard]
    let needsAttention: [BriefingCard]
    let connections: [BriefingCard]
    let generatedAt: Date

    var isEmpty: Bool {
        whatChanged.isEmpty && needsAttention.isEmpty && connections.isEmpty
    }
}

/// Loading status for the morning briefing
enum BriefingStatus: Equatable {
    case notLoaded
    case loading
    case loaded(StructuredBriefing)
    case failed(String)
}

/// State container for the morning briefing feature
struct BriefingState {
    var status: BriefingStatus = .notLoaded
}

// MARK: - Deprecated (remove after briefing redesign migration)

/// Legacy briefing struct - kept for backward compatibility during migration.
/// Will be removed when BriefingGenerator, BriefingViewModel, and BriefingView
/// are updated to use StructuredBriefing (Tasks 4, 6, 9).
@available(*, deprecated, message: "Use StructuredBriefing instead")
struct Briefing: Equatable {
    let content: String
    let suggestedThread: String?
    let threadCount: Int
    let generatedAt: Date
}
