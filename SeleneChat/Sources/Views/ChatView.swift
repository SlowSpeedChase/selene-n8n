import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @State private var messageText = ""
    @State private var showingSessionHistory = false
    @FocusState private var isInputFocused: Bool
    @Namespace private var focusNamespace

    var initialQuery: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatViewModel.currentSession.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Show thinking indicator when processing
                        if chatViewModel.isProcessing {
                            HStack {
                                ThinkingIndicator()
                                    .transition(.scale.combined(with: .opacity))
                                Spacer()
                            }
                            .id("thinking-indicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: chatViewModel.currentSession.messages.count) {
                    if let lastMessage = chatViewModel.currentSession.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chatViewModel.isProcessing) {
                    // Scroll to thinking indicator when it appears
                    if chatViewModel.isProcessing {
                        withAnimation {
                            proxy.scrollTo("thinking-indicator", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            chatInput
        }
        .focusScope(focusNamespace)
        .sheet(isPresented: $showingSessionHistory) {
            SessionHistoryView()
                .environmentObject(chatViewModel)
        }
        .onAppear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Appeared: ChatView")
            ActionTracker.shared.track(action: "viewAppeared", params: ["view": "ChatView"])
            #endif

            // Handle initial query from Today view thread tap
            if let query = initialQuery, !query.isEmpty {
                messageText = query
                // Auto-send the query
                Task {
                    await chatViewModel.sendMessage(query)
                }
                // Note: We don't clear messageText here since sendMessage handles that logic
            }
        }
        .onDisappear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Disappeared: ChatView")
            #endif
        }
    }

    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chatViewModel.currentSession.title)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: databaseService.isConnected ? "circle.fill" : "circle")
                        .foregroundColor(databaseService.isConnected ? .green : .red)
                        .font(.caption)

                    Text(databaseService.isConnected ? "Connected to Selene" : "Database disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { showingSessionHistory = true }) {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            Button(action: { chatViewModel.newSession() }) {
                Label("New Chat", systemImage: "plus.message")
            }
        }
        .padding()
    }

    private var chatInput: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask about your notes...", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .prefersDefaultFocus(in: focusNamespace)
                .lineLimit(1...5)
                .disabled(chatViewModel.isProcessing)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? .gray : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty || chatViewModel.isProcessing)
        }
        .padding()
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let message = messageText
        messageText = ""

        Task {
            await chatViewModel.sendMessage(message)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var selectedNote: Note?
    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                assistantIcon
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content with citations
                Group {
                    if let attributedContent = message.attributedContent {
                        // Use attributed text with clickable citations
                        Text(attributedContent)
                            .environment(\.openURL, OpenURLAction { url in
                                handleCitationTap(url)
                                return .handled
                            })
                    } else {
                        // Fallback to plain text
                        Text(message.content)
                    }
                }
                .padding(12)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .cornerRadius(12)
                .textSelection(.enabled)

                // Metadata
                HStack(spacing: 8) {
                    if message.role == .assistant {
                        tierBadge
                    }

                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let noteIds = message.relatedNotes, !noteIds.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                            Text("\(noteIds.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            if message.role == .user {
                userIcon
            } else {
                Spacer()
            }
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailView(note: note)
        }
    }

    private func handleCitationTap(_ url: URL) {
        // Extract citation from URL
        guard let citation = CitationParser.extractCitation(from: url) else {
            return
        }

        // Find the note in contextNotes
        if let contextNotes = message.contextNotes {
            if let note = CitationParser.findNote(for: citation, in: contextNotes) {
                selectedNote = note
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color(NSColor.controlBackgroundColor)
        case .system:
            return Color.yellow.opacity(0.2)
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    private var assistantIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 32, height: 32)

            Image(systemName: "brain.head.profile")
                .foregroundColor(.accentColor)
                .font(.system(size: 14))
        }
    }

    private var userIcon: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)

            Image(systemName: "person.fill")
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
    }

    private var tierBadge: some View {
        HStack(spacing: 2) {
            Text(message.llmTier.icon)
                .font(.caption2)
            Text(message.llmTier.rawValue)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tierColor.opacity(0.2))
        .cornerRadius(4)
    }

    private var tierColor: Color {
        switch message.llmTier {
        case .onDevice: return .green
        case .privateCloud: return .blue
        case .external: return .orange
        case .local: return .purple
        }
    }
}

struct SessionHistoryView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    var sortedSessions: [ChatSession] {
        chatViewModel.sessions.sorted { session1, session2 in
            // Pinned sessions first
            if session1.isPinned != session2.isPinned {
                return session1.isPinned
            }
            // Then by most recent update
            return session1.updatedAt > session2.updatedAt
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedSessions) { session in
                    SessionRow(session: session)
                        .onTapGesture {
                            chatViewModel.loadSession(session)
                            dismiss()
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                chatViewModel.togglePin(session)
                            } label: {
                                Label(session.isPinned ? "Unpin" : "Pin",
                                      systemImage: session.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(session.isPinned ? .orange : .blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                chatViewModel.deleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 550)
    }
}

struct SessionRow: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with pin indicator
            HStack(spacing: 6) {
                if session.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Text(session.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                compressionBadge
            }

            // Metadata row
            HStack {
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(session.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Summary text for compressed sessions
            if session.compressionState == .compressed, let summary = session.summaryText {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var compressionBadge: some View {
        switch session.compressionState {
        case .full:
            Text("Full")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(4)

        case .processing:
            Text("Processing")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)

        case .compressed:
            Text("Summary")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
    }
}
