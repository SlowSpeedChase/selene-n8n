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
    private let maxSizeBytes: Int
    private let dateFormatter: DateFormatter
    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.selenechat.debuglogger")

    init(logPath: String = "/tmp/selenechat-debug.log", maxSizeBytes: Int = 5 * 1024 * 1024) {
        self.logPath = logPath
        self.maxSizeBytes = maxSizeBytes

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        self.fileHandle = openLogFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    func log(_ category: LogCategory, _ message: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.rotateIfNeeded()

            let timestamp = self.dateFormatter.string(from: Date())
            let logLine = "[\(timestamp)] \(category.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(message)\n"

            if let data = logLine.data(using: .utf8) {
                self.fileHandle?.write(data)
                try? self.fileHandle?.synchronize()
            }
        }
    }

    private func openLogFile() -> FileHandle? {
        // Create file if doesn't exist
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }

        let handle = FileHandle(forWritingAtPath: logPath)
        handle?.seekToEndOfFile()
        return handle
    }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logPath),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxSizeBytes else {
            return
        }

        // Close current handle
        try? fileHandle?.close()

        let backupPath = logPath + ".old"

        // Delete old backup if exists
        try? FileManager.default.removeItem(atPath: backupPath)

        // Move current to backup
        try? FileManager.default.moveItem(atPath: logPath, toPath: backupPath)

        // Open fresh file
        self.fileHandle = openLogFile()
    }
}

#endif
