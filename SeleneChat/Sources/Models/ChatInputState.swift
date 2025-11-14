import Foundation
import SwiftUI

// GREEN: Minimal implementation to make tests pass
@MainActor
class ChatInputState: ObservableObject {
    @Published var messageText: String = ""
    @Published var isFocused: Bool = false
    @Published var isProcessing: Bool = false

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    func requestFocus() {
        isFocused = true
    }

    func clearFocus() {
        isFocused = false
    }

    func clear() {
        messageText = ""
    }
}
