import Foundation

/// Represents a parsed citation from text
struct ParsedCitation: Identifiable {
    let id = UUID()
    let noteTitle: String
    let noteDate: String
    let range: Range<String.Index>
    let displayText: String  // Formatted for display: "[Title - Date]"
}

/// Parser for extracting citation patterns from text
class CitationParser {
    /// Parse text and extract citations
    /// Returns plain text and array of citations with their positions
    static func parse(_ text: String) -> (plainText: String, citations: [ParsedCitation]) {
        // Regex pattern: [Note: 'Title' - Date]
        let pattern = #"\[Note: '([^']+)' - ([^\]]+)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("CitationParser: Failed to create regex")
            return (text, [])
        }

        var citations: [ParsedCitation] = []
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            // Extract title (capture group 1)
            let titleRange = match.range(at: 1)
            // Extract date (capture group 2)
            let dateRange = match.range(at: 2)
            // Full match range
            let fullRange = match.range

            let title = nsString.substring(with: titleRange)
            let date = nsString.substring(with: dateRange)

            // Convert NSRange to Range<String.Index>
            guard let swiftRange = Range(fullRange, in: text) else {
                print("CitationParser: Failed to convert range for citation: \(title)")
                continue
            }

            let citation = ParsedCitation(
                noteTitle: title,
                noteDate: date,
                range: swiftRange,
                displayText: "[\(title) - \(date)]"
            )

            citations.append(citation)
        }

        print("CitationParser: Found \(citations.count) citations in text")
        return (text, citations)
    }

    /// Find matching note from list by title and date
    static func findNote(for citation: ParsedCitation, in notes: [Note]) -> Note? {
        // Match by title (exact match preferred)
        let exactMatch = notes.first { $0.title == citation.noteTitle }
        if exactMatch != nil {
            print("CitationParser: Found exact match for citation: \(citation.noteTitle)")
            return exactMatch
        }

        // Fallback: case-insensitive match
        let caseInsensitiveMatch = notes.first {
            $0.title.lowercased() == citation.noteTitle.lowercased()
        }

        if caseInsensitiveMatch != nil {
            print("CitationParser: Found case-insensitive match for citation: \(citation.noteTitle)")
        } else {
            print("CitationParser: No match found for citation: \(citation.noteTitle)")
        }

        return caseInsensitiveMatch
    }
}
