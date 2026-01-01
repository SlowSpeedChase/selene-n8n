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

struct PlanningConversationView: View {
    let thread: DiscussionThread
    let onBack: () -> Void

    @EnvironmentObject var databaseService: DatabaseService
    @State private var messages: [PlanningMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var conversationHistory: [[String: String]] = []
    @State private var tasksCreated: [String] = []
    @FocusState private var isInputFocused: Bool
    @State private var currentProvider: AIProvider = .local
    @State private var showProviderSettings = false
    @State private var showHistoryPrompt = false
    @StateObject private var providerService = AIProviderService.shared

    private let claudeService = ClaudeAPIService.shared
    private let thingsService = ThingsURLService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            conversationHeader

            Divider()

            // Original note context
            noteContextCard

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { message in
                            PlanningMessageBubble(message: message)
                                .id(message.id)
                        }

                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .id("processing")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            inputArea
        }
        .task {
            await startConversation()
        }
    }

    private var conversationHeader: some View {
        HStack {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            // Provider toggle badge
            providerBadge

            if !tasksCreated.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(tasksCreated.count) tasks")
                        .font(.caption)
                }
            }

            Spacer()

            // Settings gear
            Button(action: { showProviderSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showProviderSettings) {
                AIProviderSettings(providerService: providerService)
            }

            Button("Complete") {
                Task { await completeThread() }
            }
            .disabled(isProcessing)
        }
        .padding()
        .alert("Switch to Cloud AI", isPresented: $showHistoryPrompt) {
            Button("Yes, send history") {
                currentProvider = .cloud
            }
            Button("No, fresh start") {
                currentProvider = .cloud
                conversationHistory = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Include conversation history? This will send previous messages to Claude API.")
        }
    }

    private var providerBadge: some View {
        Button(action: toggleProvider) {
            HStack(spacing: 4) {
                Text(currentProvider.icon)
                Text(currentProvider.displayName)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(currentProvider == .cloud ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func toggleProvider() {
        if currentProvider == .local {
            // Switching to cloud - ask about history
            showHistoryPrompt = true
        } else {
            // Switching to local - no prompt needed
            currentProvider = .local
        }
    }

    private var noteContextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = thread.noteTitle {
                Text(title)
                    .font(.headline)
            }

            if let content = thread.noteContent {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.05))
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Your response...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .disabled(isProcessing)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .gray : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || isProcessing)
        }
        .padding()
    }

    private func startConversation() async {
        // Mark thread as active
        try? await databaseService.updateThreadStatus(thread.id, status: .active)

        // Add initial AI message based on thread prompt
        let systemPrompt = buildSystemPrompt()

        isProcessing = true

        do {
            let response = try await claudeService.sendPlanningMessage(
                userMessage: "Start the planning session.",
                conversationHistory: [],
                systemPrompt: systemPrompt
            )

            conversationHistory.append(["role": "user", "content": "Start the planning session."])
            conversationHistory.append(["role": "assistant", "content": response.message])

            messages.append(PlanningMessage(
                role: .assistant,
                content: response.cleanMessage
            ))

            // Handle any extracted tasks
            await handleExtractedTasks(response.extractedTasks)

        } catch {
            messages.append(PlanningMessage(
                role: .system,
                content: "Failed to start conversation: \(error.localizedDescription)"
            ))
        }

        isProcessing = false
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userInput = inputText
        inputText = ""

        // Add user message
        messages.append(PlanningMessage(role: .user, content: userInput))
        conversationHistory.append(["role": "user", "content": userInput])

        isProcessing = true

        Task {
            do {
                let response = try await claudeService.sendPlanningMessage(
                    userMessage: userInput,
                    conversationHistory: conversationHistory,
                    systemPrompt: buildSystemPrompt()
                )

                conversationHistory.append(["role": "assistant", "content": response.message])

                messages.append(PlanningMessage(
                    role: .assistant,
                    content: response.cleanMessage
                ))

                // Handle any extracted tasks
                await handleExtractedTasks(response.extractedTasks)

            } catch {
                messages.append(PlanningMessage(
                    role: .system,
                    content: "Error: \(error.localizedDescription)"
                ))
            }

            isProcessing = false
        }
    }

    private func handleExtractedTasks(_ tasks: [ExtractedTask]) async {
        for task in tasks {
            do {
                try await thingsService.createTask(
                    title: task.title,
                    notes: nil,
                    tags: [],
                    energy: task.energy,
                    sourceNoteId: thread.rawNoteId,
                    threadId: thread.id
                )

                tasksCreated.append(task.title)

                // Show confirmation in chat
                messages.append(PlanningMessage(
                    role: .taskCreated,
                    content: task.title
                ))

            } catch {
                messages.append(PlanningMessage(
                    role: .system,
                    content: "Failed to create task: \(error.localizedDescription)"
                ))
            }
        }
    }

    private func completeThread() async {
        try? await databaseService.updateThreadStatus(thread.id, status: .completed)
        onBack()
    }

    private func buildSystemPrompt() -> String {
        """
        You are a planning assistant helping break down goals into actionable tasks.
        Ask ONE question at a time. When the user's response contains a clear,
        specific action, extract it as a task.

        Context:
        - Original note: \(thread.noteContent ?? "No content")
        - Planning prompt: \(thread.prompt)
        - Tasks already created: \(tasksCreated.joined(separator: ", "))

        Your question types (cycle through as needed):
        1. "What's the first concrete step you could take?"
        2. "What's blocking you from starting?"
        3. "Can you break that down smaller?"
        4. "What would 'done' look like for this?"
        5. "What's the next step after that?"

        When extracting a task, include in your response:
        [TASK: verb + object | energy: low/medium/high | minutes: 5/15/30/60/120/240]

        When planning feels complete, ask: "Does this cover what you need,
        or is there more to plan?"
        """
    }
}

// MARK: - Planning Message Model

struct PlanningMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    let provider: AIProvider  // Track which AI generated this

    enum Role {
        case user
        case assistant
        case system
        case taskCreated
    }

    init(role: Role, content: String, provider: AIProvider = .local) {
        self.role = role
        self.content = content
        self.provider = provider
    }
}

struct PlanningMessageBubble: View {
    let message: PlanningMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            content
                .padding(12)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .cornerRadius(12)

            if message.role != .user { Spacer() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.role {
        case .taskCreated:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Task created: \(message.content)")
            }
            .font(.callout)
        default:
            Text(message.content)
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return Color.accentColor
        case .assistant: return Color(NSColor.controlBackgroundColor)
        case .system: return Color.orange.opacity(0.2)
        case .taskCreated: return Color.green.opacity(0.1)
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}
