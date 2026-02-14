import Foundation
import SwiftUI

@MainActor
public class ChatInputState: ObservableObject {
    @Published public var messageText: String = ""
    @Published public var isFocused: Bool = false
    @Published public var isProcessing: Bool = false

    public init() {}

    public var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    public func requestFocus() {
        isFocused = true
    }

    public func clearFocus() {
        isFocused = false
    }

    public func clear() {
        messageText = ""
    }
}
