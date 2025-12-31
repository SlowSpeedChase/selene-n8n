// SeleneChat/Sources/Views/PlanningView.swift
import SwiftUI

struct PlanningView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var threads: [DiscussionThread] = []
    @State private var selectedThread: DiscussionThread?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let thread = selectedThread {
                PlanningConversationView(
                    thread: thread,
                    onBack: { selectedThread = nil }
                )
            } else {
                threadListView
            }
        }
        .task {
            await loadThreads()
        }
    }

    private var threadListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planning")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Threads to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { Task { await loadThreads() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading threads...")
                Spacer()
            } else if let error = error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        Task { await loadThreads() }
                    }
                }
                Spacer()
            } else if threads.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Nothing to plan right now")
                        .font(.headline)
                    Text("Notes flagged as 'needs planning' will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(threads) { thread in
                            PlanningThreadRow(thread: thread)
                                .onTapGesture {
                                    selectedThread = thread
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func loadThreads() async {
        isLoading = true
        error = nil

        do {
            threads = try await databaseService.getPendingThreads()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct PlanningThreadRow: View {
    let thread: DiscussionThread

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type badge
            HStack {
                Label(thread.threadType.displayName, systemImage: thread.threadType.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Image(systemName: thread.status.icon)
                    Text(thread.timeSinceCreated)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // Prompt
            Text(thread.prompt)
                .font(.body)
                .lineLimit(2)

            // Note title if available
            if let noteTitle = thread.noteTitle {
                Text("From: \(noteTitle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Resurface reason if applicable
            if let reason = thread.resurfaceReason {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(reason.message)
                }
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}

// Placeholder for conversation view - will be implemented in Task 8
struct PlanningConversationView: View {
    let thread: DiscussionThread
    let onBack: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Label("Back to threads", systemImage: "chevron.left")
                }
                Spacer()
            }
            .padding()

            Divider()

            Text("Planning conversation for: \(thread.prompt)")
                .padding()

            Spacer()
        }
    }
}
