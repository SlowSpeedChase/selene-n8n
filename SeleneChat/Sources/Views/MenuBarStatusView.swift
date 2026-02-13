import SwiftUI

/// Minimal status dropdown view for the menu bar popover.
///
/// Displays the current workflow scheduler status (active/idle),
/// an "Open Selene" button to bring the main window to front,
/// and a "Quit" button to terminate the app.
struct MenuBarStatusView: View {
    @EnvironmentObject var scheduler: WorkflowScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusLine
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            openSeleneButton
                .padding(.horizontal, 4)
                .padding(.top, 4)

            quitButton
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .frame(width: 200)
    }

    // MARK: - Status Line

    private var isActive: Bool {
        !scheduler.activeWorkflows.isEmpty
    }

    private var statusDotSymbol: String {
        isActive ? "circle.fill" : "circle"
    }

    private var statusDotColor: Color {
        isActive ? .green : .secondary
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            Image(systemName: statusDotSymbol)
                .font(.system(size: 8))
                .foregroundColor(statusDotColor)

            Text(scheduler.statusText)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Buttons

    private var openSeleneButton: some View {
        Button(action: openSelene) {
            HStack {
                Text("Open Selene")
                Spacer()
                Text("\u{2318}O")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .keyboardShortcut("o", modifiers: .command)
    }

    private var quitButton: some View {
        Button(action: quitApp) {
            HStack {
                Text("Quit")
                Spacer()
                Text("\u{2318}Q")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Actions

    private func openSelene() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Preview

#if DEBUG
struct MenuBarStatusView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarStatusView()
            .environmentObject(WorkflowScheduler())
            .previewDisplayName("Idle")
    }
}
#endif
