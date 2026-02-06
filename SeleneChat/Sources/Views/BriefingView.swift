// SeleneChat/Sources/Views/BriefingView.swift
import SwiftUI

struct BriefingView: View {
    @StateObject private var viewModel = BriefingViewModel()

    var onDismiss: () -> Void
    var onDigIn: (String) -> Void

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            content
        }
        .onAppear {
            if case .notLoaded = viewModel.state.status {
                Task {
                    await viewModel.loadBriefing()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.status {
        case .notLoaded:
            EmptyView()

        case .loading:
            loadingView

        case .loaded(let briefing):
            loadedView(briefing)

        case .failed(let message):
            errorView(message)
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Preparing your morning briefing...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Loaded State

    private func loadedView(_ briefing: Briefing) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Briefing content card
            VStack(alignment: .leading, spacing: 16) {
                Text(briefing.content)
                    .font(.body)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 500)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(16)

            // Action buttons
            VStack(spacing: 12) {
                // Primary action: Dig in
                Button(action: {
                    Task {
                        let query = await viewModel.digIn()
                        onDigIn(query)
                    }
                }) {
                    Text("Yes, let's dig in")
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Secondary action: Show something else
                Button(action: {
                    Task {
                        let query = await viewModel.showSomethingElse()
                        onDigIn(query)
                    }
                }) {
                    Text("Show me something else")
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                // Tertiary action: Skip
                Button(action: {
                    onDismiss()
                }) {
                    Text("Skip")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Error State

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Couldn't generate briefing")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            VStack(spacing: 12) {
                Button("Try Again") {
                    Task {
                        await viewModel.loadBriefing()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Skip") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}
