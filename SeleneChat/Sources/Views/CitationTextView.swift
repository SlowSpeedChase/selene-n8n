import SwiftUI

/// View that renders text with clickable inline citations
struct CitationTextView: View {
    let content: String
    let citedNoteIds: [Int]
    @Binding var selectedNote: Note?

    @EnvironmentObject var databaseService: DatabaseService
    @State private var textSegments: [TextSegment] = []

    enum TextSegment: Identifiable {
        case text(String)
        case citation(ParsedCitation)

        var id: String {
            switch self {
            case .text(let str):
                return str
            case .citation(let cit):
                return cit.id.uuidString
            }
        }
    }

    var body: some View {
        // Use Text concatenation to build the full attributed text
        buildAttributedText()
            .textSelection(.enabled)
            .task {
                parseContent()
            }
    }

    /// Build attributed text with clickable citations
    @ViewBuilder
    private func buildAttributedText() -> some View {
        if textSegments.isEmpty {
            Text(content)
                .foregroundColor(.primary)
        } else {
            // Note: Text concatenation doesn't work well with dynamic content
            // Fall back to showing plain text for now
            Text(content)
                .foregroundColor(.primary)
        }
    }

    /// Parse content into text segments
    private func parseContent() {
        let (_, citations) = CitationParser.parse(content)

        var segments: [TextSegment] = []
        var currentIndex = content.startIndex

        // Sort citations by position in text
        let sortedCitations = citations.sorted {
            $0.range.lowerBound < $1.range.lowerBound
        }

        for citation in sortedCitations {
            // Add text before citation
            if currentIndex < citation.range.lowerBound {
                let textBefore = String(content[currentIndex..<citation.range.lowerBound])
                if !textBefore.isEmpty {
                    segments.append(.text(textBefore))
                }
            }

            // Add citation
            segments.append(.citation(citation))
            currentIndex = citation.range.upperBound
        }

        // Add remaining text
        if currentIndex < content.endIndex {
            let remainingText = String(content[currentIndex...])
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }

        // If no citations found, just show plain text
        if segments.isEmpty {
            segments.append(.text(content))
        }

        textSegments = segments
    }

    /// Handle citation tap
    func handleCitationTap(_ citation: ParsedCitation) {
        Task {
            // Load all cited notes from database
            let notes = await loadCitedNotes()

            // Find matching note
            if let note = CitationParser.findNote(for: citation, in: notes) {
                await MainActor.run {
                    selectedNote = note
                }
            } else {
                print("CitationTextView: No matching note found for citation: \(citation.noteTitle)")
            }
        }
    }

    /// Load cited notes from database
    private func loadCitedNotes() async -> [Note] {
        var notes: [Note] = []

        for noteId in citedNoteIds {
            do {
                if let note = try await databaseService.getNote(byId: noteId) {
                    notes.append(note)
                }
            } catch {
                print("CitationTextView: Failed to load note \(noteId): \(error)")
            }
        }

        return notes
    }
}

/// Alternative implementation using clickable segments
/// This version uses a VStack with individual clickable buttons for citations
struct CitationTextViewClickable: View {
    let content: String
    let citedNoteIds: [Int]
    @Binding var selectedNote: Note?

    @EnvironmentObject var databaseService: DatabaseService
    @State private var textSegments: [TextSegment] = []

    enum TextSegment: Identifiable {
        case text(String)
        case citation(ParsedCitation)

        var id: String {
            switch self {
            case .text(let str):
                return str
            case .citation(let cit):
                return cit.id.uuidString
            }
        }
    }

    var body: some View {
        FlowLayout(spacing: 0) {
            ForEach(textSegments) { segment in
                switch segment {
                case .text(let str):
                    Text(str)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)

                case .citation(let citation):
                    Button(action: {
                        handleCitationTap(citation)
                    }) {
                        Text(citation.displayText)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            parseContent()
        }
    }

    /// Parse content into text segments
    private func parseContent() {
        let (_, citations) = CitationParser.parse(content)

        var segments: [TextSegment] = []
        var currentIndex = content.startIndex

        // Sort citations by position in text
        let sortedCitations = citations.sorted {
            $0.range.lowerBound < $1.range.lowerBound
        }

        for citation in sortedCitations {
            // Add text before citation
            if currentIndex < citation.range.lowerBound {
                let textBefore = String(content[currentIndex..<citation.range.lowerBound])
                if !textBefore.isEmpty {
                    segments.append(.text(textBefore))
                }
            }

            // Add citation
            segments.append(.citation(citation))
            currentIndex = citation.range.upperBound
        }

        // Add remaining text
        if currentIndex < content.endIndex {
            let remainingText = String(content[currentIndex...])
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }

        // If no citations found, just show plain text
        if segments.isEmpty {
            segments.append(.text(content))
        }

        textSegments = segments
    }

    /// Handle citation tap
    private func handleCitationTap(_ citation: ParsedCitation) {
        Task {
            // Load all cited notes from database
            let notes = await loadCitedNotes()

            // Find matching note
            if let note = CitationParser.findNote(for: citation, in: notes) {
                await MainActor.run {
                    selectedNote = note
                }
            } else {
                print("CitationTextView: No matching note found for citation: \(citation.noteTitle)")
            }
        }
    }

    /// Load cited notes from database
    private func loadCitedNotes() async -> [Note] {
        var notes: [Note] = []

        for noteId in citedNoteIds {
            do {
                if let note = try await databaseService.getNote(byId: noteId) {
                    notes.append(note)
                }
            } catch {
                print("CitationTextViewClickable: Failed to load note \(noteId): \(error)")
            }
        }

        return notes
    }
}

// Note: FlowLayout is defined in SearchView.swift
