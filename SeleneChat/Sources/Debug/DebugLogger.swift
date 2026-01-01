import Foundation

#if DEBUG

enum LogCategory: String {
    case state = "STATE"
    case error = "ERROR"
    case nav = "NAV"
    case action = "ACTION"
}

final class DebugLogger {
    static let shared = DebugLogger()

    private let logPath: String
    private let dateFormatter: DateFormatter
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.selenechat.debuglogger")

    init(logPath: String = "/tmp/selenechat-debug.log") {
        self.logPath = logPath

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        // Create file if doesn't exist
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }

        self.fileHandle = FileHandle(forWritingAtPath: logPath)
        self.fileHandle?.seekToEndOfFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    func log(_ category: LogCategory, _ message: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = self.dateFormatter.string(from: Date())
            let logLine = "[\(timestamp)] \(category.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(message)\n"

            if let data = logLine.data(using: .utf8) {
                self.fileHandle?.write(data)
                try? self.fileHandle?.synchronize()
            }
        }
    }
}

#endif
