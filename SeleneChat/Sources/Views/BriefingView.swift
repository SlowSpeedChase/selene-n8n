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

    private func loadedView(_ briefing: StructuredBriefing) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Briefing content card (legacy - will be replaced in Task 6)
            VStack(alignment: .leading, spacing: 16) {
                Text(briefing.intro)
                    .font(.body)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 500)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(16)

            // Action buttons (will be replaced by card-based navigation in Task 6)
            VStack(spacing: 12) {
                // Primary action: Dismiss to chat
                Button(action: {
                    onDismiss()
                }) {
                    Text("Got it, let's go")
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Skip
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
