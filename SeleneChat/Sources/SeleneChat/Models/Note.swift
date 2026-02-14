import Foundation

struct Note: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let content: String
    let contentHash: String
    let sourceType: String
    let wordCount: Int
    let characterCount: Int
    let tags: [String]?
    let createdAt: Date
    let importedAt: Date
    let processedAt: Date?
    let exportedAt: Date?
    let status: String
    let exportedToObsidian: Bool
    let sourceUUID: String?
    let testRun: String?

    // Processed note data (from join)
    var concepts: [String]?
    var conceptConfidence: [String: Double]?
    var primaryTheme: String?
    var secondaryThemes: [String]?
    var themeConfidence: Double?
    var overallSentiment: String?
    var sentimentScore: Double?
    var emotionalTone: String?
    var energyLevel: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case contentHash = "content_hash"
        case sourceType = "source_type"
        case wordCount = "word_count"
        case characterCount = "character_count"
        case tags
        case createdAt = "created_at"
        case importedAt = "imported_at"
        case processedAt = "processed_at"
        case exportedAt = "exported_at"
        case status
        case exportedToObsidian = "exported_to_obsidian"
        case sourceUUID = "source_uuid"
        case testRun = "test_run"
        case concepts
        case conceptConfidence = "concept_confidence"
        case primaryTheme = "primary_theme"
        case secondaryThemes = "secondary_themes"
        case themeConfidence = "theme_confidence"
        case overallSentiment = "overall_sentiment"
        case sentimentScore = "sentiment_score"
        case emotionalTone = "emotional_tone"
        case energyLevel = "energy_level"
    }

    var energyEmoji: String {
        switch energyLevel?.lowercased() {
        case "high": return "⚡"
        case "medium": return "🔋"
        case "low": return "🪫"
        default: return "🔋"
        }
    }

    var sentimentEmoji: String {
        switch overallSentiment?.lowercased() {
        case "positive": return "😊"
        case "negative": return "😔"
        case "neutral": return "😐"
        default: return "😐"
        }
    }

    var moodEmoji: String {
        switch emotionalTone?.lowercased() {
        case "excited": return "🚀"
        case "calm": return "😌"
        case "anxious": return "😰"
        case "frustrated": return "😤"
        case "happy": return "😊"
        case "sad": return "😢"
        default: return "😐"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var preview: String {
        String(content.prefix(200))
    }
}

#if DEBUG
extension Note {
    static func mock(
        id: Int = 1,
        title: String = "Test Note",
        content: String = "Test content",
        contentHash: String = "mock-hash",
        sourceType: String = "test",
        wordCount: Int = 2,
        characterCount: Int = 12,
        tags: [String]? = nil,
        createdAt: Date = Date(),
        importedAt: Date = Date(),
        processedAt: Date? = nil,
        exportedAt: Date? = nil,
        status: String = "processed",
        exportedToObsidian: Bool = false,
        sourceUUID: String? = nil,
        testRun: String? = nil,
        concepts: [String]? = nil,
        conceptConfidence: [String: Double]? = nil,
        primaryTheme: String? = nil,
        secondaryThemes: [String]? = nil,
        themeConfidence: Double? = nil,
        overallSentiment: String? = nil,
        sentimentScore: Double? = nil,
        emotionalTone: String? = nil,
        energyLevel: String? = nil
    ) -> Note {
        var note = Note(
            id: id,
            title: title,
            content: content,
            contentHash: contentHash,
            sourceType: sourceType,
            wordCount: wordCount,
            characterCount: characterCount,
            tags: tags,
            createdAt: createdAt,
            importedAt: importedAt,
            processedAt: processedAt,
            exportedAt: exportedAt,
            status: status,
            exportedToObsidian: exportedToObsidian,
            sourceUUID: sourceUUID,
            testRun: testRun
        )
        note.concepts = concepts
        note.conceptConfidence = conceptConfidence
        note.primaryTheme = primaryTheme
        note.secondaryThemes = secondaryThemes
        note.themeConfidence = themeConfidence
        note.overallSentiment = overallSentiment
        note.sentimentScore = sentimentScore
        note.emotionalTone = emotionalTone
        note.energyLevel = energyLevel
        return note
    }
}
#endif
