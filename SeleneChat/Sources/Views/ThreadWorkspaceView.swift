// ThreadWorkspaceView.swift
// SeleneChat
//
// Thread Workspace: Thread context, tasks, notes, and scoped chat in one view.
// Phase 2: Chat with task creation via action confirmation

import SwiftUI

struct ThreadWorkspaceView: View {
    let threadId: Int64

    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var thread: Thread?
    @State private var tasks: [ThreadTask] = []
    @State private var notes: [Note] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var chatViewModel: ThreadWorkspaceChatViewModel?
    @State private var chatInput = ""
    @State private var isConfirmingActions = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if let thread = thread {
                HSplitView {
                    // Left: Thread context, tasks, notes
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            threadContextSection(thread)
                            tasksSection
                            notesSection
                        }
                        .padding()
                    }
                    .frame(minWidth: 280)

                    // Right: Chat
                    chatSection
                        .frame(minWidth: 300)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            await loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Thread Workspace")
                .font(.headline)

            Spacer()

            Button(action: { Task { await loadData() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Thread Context

    private func threadContextSection(_ thread: Thread) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name and status
            HStack {
                Text(thread.statusEmoji)
                Text(thread.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                momentumIndicator(thread.momentumScore)
            }

            // Why (motivation)
            if let why = thread.why, !why.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHY")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(why)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Summary
            if let summary = thread.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT STATE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(summary)
                        .font(.body)
                }
            }

            // Metadata
            HStack(spacing: 16) {
                Label("\(thread.noteCount) notes", systemImage: "note.text")
                Label(thread.lastActivityDisplay, systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func momentumIndicator(_ score: Double?) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(i < Int((score ?? 0) * 5) ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TASKS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            if tasks.isEmpty {
                emptyTasksView
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private var emptyTasksView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No tasks linked to this thread yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Tasks created in chat will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func taskRow(_ task: ThreadTask) -> some View {
        HStack(spacing: 12) {
            // Completion indicator
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? task.thingsTaskId)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                if task.isCompleted {
                    Text(task.completedDisplay)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Open in Things button
            Button(action: { openInThings(task.thingsTaskId) }) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOTES IN THIS THREAD")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(notes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            if notes.isEmpty {
                Text("No notes linked yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(notes.prefix(5)) { note in
                        noteRow(note)
                    }
                    if notes.count > 5 {
                        Text("+ \(notes.count - 5) more notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text(note.relativeDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(String(note.content.prefix(100)))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Text("CHAT")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                if let vm = chatViewModel, vm.isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if let vm = chatViewModel {
                            if vm.messages.isEmpty {
                                chatEmptyState
                            } else {
                                ForEach(vm.messages) { message in
                                    chatMessageRow(message)
                                        .id(message.id)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatViewModel?.messages.count) {
                    if let lastId = chatViewModel?.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Pending actions banner
            if let vm = chatViewModel, !vm.pendingActions.isEmpty {
                pendingActionsBanner(vm.pendingActions)
            }

            Divider()

            // Input
            chatInputArea
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var chatEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Ask about this thread")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("\"What should I focus on next?\" or \"Break this down into tasks\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func chatMessageRow(_ message: Message) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.isUser ? "You" : "Selene")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .font(.body)
                    .padding(10)
                    .background(message.isUser ? Color.blue.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - Pending Actions Banner

    private func pendingActionsBanner(_ actions: [ActionExtractor.ExtractedAction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("Suggested Tasks (\(actions.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                HStack(spacing: 8) {
                    Circle()
                        .fill(energyColor(action.energy))
                        .frame(width: 8, height: 8)
                    Text(action.description)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(action.timeframe.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button("Create in Things") {
                    confirmPendingActions()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isConfirmingActions)

                if isConfirmingActions {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                Spacer()

                Button("Dismiss") {
                    chatViewModel?.dismissActions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func energyColor(_ energy: ActionExtractor.ExtractedAction.EnergyLevel) -> Color {
        switch energy {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    // MARK: - Chat Input

    private var chatInputArea: some View {
        HStack(spacing: 8) {
            TextField("Ask about this thread...", text: $chatInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { sendChatMessage() }

            Button(action: { sendChatMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(chatInput.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(chatInput.trimmingCharacters(in: .whitespaces).isEmpty || (chatViewModel?.isProcessing ?? false))
        }
        .padding()
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading thread...")
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Couldn't load thread")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Try Again") {
                Task { await loadData() }
            }
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Load thread details
            thread = try await databaseService.getThreadById(threadId)

            guard let loadedThread = thread else {
                error = "Thread not found"
                return
            }

            // Load tasks for thread
            tasks = try await databaseService.getTasksForThread(threadId)

            // Load notes for thread
            if let result = try await databaseService.getThreadByName(loadedThread.name) {
                notes = result.1
            }

            // Initialize chat VM with loaded data
            if chatViewModel == nil {
                chatViewModel = ThreadWorkspaceChatViewModel(
                    thread: loadedThread,
                    notes: notes,
                    tasks: tasks
                )
            } else {
                chatViewModel?.updateTasks(tasks)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Actions

    private func openInThings(_ taskId: String) {
        let urlString = "things:///show?id=\(taskId)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func sendChatMessage() {
        let content = chatInput.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty, let vm = chatViewModel else { return }
        chatInput = ""

        Task {
            await vm.sendMessage(content)
        }
    }

    private func confirmPendingActions() {
        guard let vm = chatViewModel else { return }
        isConfirmingActions = true

        Task {
            let createdIds = await vm.confirmActions()
            isConfirmingActions = false

            // Reload tasks to show newly created ones
            if !createdIds.isEmpty {
                do {
                    tasks = try await databaseService.getTasksForThread(threadId)
                } catch {
                    print("[ThreadWorkspaceView] Failed to reload tasks: \(error)")
                }
            }
        }
    }
}

// MARK: - Note Extension

extension Note {
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

#if DEBUG
struct ThreadWorkspaceView_Previews: PreviewProvider {
    static var previews: some View {
        ThreadWorkspaceView(threadId: 1)
            .environmentObject(DatabaseService.shared)
    }
}
#endif
