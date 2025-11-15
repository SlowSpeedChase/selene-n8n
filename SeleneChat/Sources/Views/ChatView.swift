import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @State private var messageText = ""
    @State private var showingSessionHistory = false
    @FocusState private var isInputFocused: Bool
    @Namespace private var focusNamespace

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
                // Message content with clickable citations for assistant
                if message.role == .assistant,
                   let citedNotes = message.relatedNotes,
                   !citedNotes.isEmpty {
                    CitationTextViewClickable(
                        content: message.content,
                        citedNoteIds: citedNotes,
                        selectedNote: $selectedNote
                    )
                    .padding(12)
                    .background(backgroundColor)
                    .cornerRadius(12)
                } else {
                    Text(message.content)
                        .padding(12)
                        .background(backgroundColor)
                        .foregroundColor(textColor)
                        .cornerRadius(12)
                        .textSelection(.enabled)
                }

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

    var body: some View {
        NavigationStack {
            List {
                ForEach(chatViewModel.sessions.sorted(by: { $0.updatedAt > $1.updatedAt })) { session in
                    Button(action: {
                        chatViewModel.loadSession(session)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)

                            HStack {
                                Text(session.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(session.messages.count) messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    let sortedSessions = chatViewModel.sessions.sorted(by: { $0.updatedAt > $1.updatedAt })
                    indexSet.forEach { index in
                        chatViewModel.deleteSession(sortedSessions[index])
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
        .frame(width: 400, height: 500)
    }
}
