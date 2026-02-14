import SeleneShared
// SeleneChat/Sources/Views/RelatedNotesView.swift

import SwiftUI

/// Displays notes related to a given note with relationship type badges
struct RelatedNotesView: View {
    let noteId: Int
    @State private var relatedNotes: [(note: Note, relationshipType: String, strength: Double?)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if relatedNotes.isEmpty {
                emptyView
            } else {
                notesList
            }
        }
        .task {
            await loadRelatedNotes()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.secondary)
            Text("Related Notes")
                .font(.headline)
            Spacer()
            if !isLoading && !relatedNotes.isEmpty {
                Text("\(relatedNotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Finding related notes...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var emptyView: some View {
        Text("No related notes found")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }

    private var notesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(relatedNotes, id: \.note.id) { item in
                RelatedNoteRow(
                    note: item.note,
                    relationshipType: item.relationshipType,
                    strength: item.strength
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadRelatedNotes() async {
        isLoading = true
        errorMessage = nil

        let results = await databaseService.getRelatedNotes(for: noteId, limit: 5)

        await MainActor.run {
            self.relatedNotes = results
            self.isLoading = false
        }
    }
}

/// Row displaying a single related note with relationship badge
struct RelatedNoteRow: View {
    let note: Note
    let relationshipType: String
    let strength: Double?

    var body: some View {
        HStack(spacing: 8) {
            relationshipBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(note.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let strength = strength {
                Text(String(format: "%.0f%%", strength * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    private var relationshipBadge: some View {
        Text(badgeText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }

    private var badgeText: String {
        switch relationshipType {
        case "SAME_THREAD": return "Thread"
        case "TEMPORAL": return "Time"
        case "EMBEDDING": return "Similar"
        default: return relationshipType
        }
    }

    private var badgeColor: Color {
        switch relationshipType {
        case "SAME_THREAD": return .purple
        case "TEMPORAL": return .blue
        case "EMBEDDING": return .green
        default: return .gray
        }
    }
}

#if DEBUG
struct RelatedNotesView_Previews: PreviewProvider {
    static var previews: some View {
        RelatedNotesView(noteId: 1)
            .environmentObject(DatabaseService.shared)
            .frame(width: 300)
            .padding()
    }
}
#endif
