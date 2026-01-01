// SeleneChat/Sources/Views/AIProviderSettings.swift
import SwiftUI

struct AIProviderSettings: View {
    @ObservedObject var providerService: AIProviderService
    @State private var ollamaStatus: Bool?
    @State private var claudeStatus: Bool?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Planning Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }

            Divider()

            // Default Provider Toggle
            VStack(alignment: .leading, spacing: 8) {
                Text("Default AI Provider")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Provider", selection: $providerService.globalDefault) {
                    Label("Local (Ollama)", systemImage: "house.fill")
                        .tag(AIProvider.local)
                    Label("Cloud (Claude)", systemImage: "cloud.fill")
                        .tag(AIProvider.cloud)
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Provider Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Provider Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Label("Ollama", systemImage: "house.fill")
                    Spacer()
                    statusIndicator(for: ollamaStatus, label: "Connected", errorLabel: "Offline")
                }

                HStack {
                    Label("Claude API", systemImage: "cloud.fill")
                    Spacer()
                    statusIndicator(for: claudeStatus, label: "API key configured", errorLabel: "API key not found")
                }
            }
        }
        .padding()
        .frame(width: 300)
        .task {
            await checkStatus()
        }
    }

    @ViewBuilder
    private func statusIndicator(for status: Bool?, label: String, errorLabel: String) -> some View {
        if let status = status {
            if status {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            ProgressView()
                .scaleEffect(0.7)
        }
    }

    private func checkStatus() async {
        ollamaStatus = await providerService.isLocalAvailable()
        claudeStatus = await providerService.isCloudAvailable()
    }
}
