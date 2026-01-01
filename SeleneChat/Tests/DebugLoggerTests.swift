import XCTest
@testable import SeleneChat

final class DebugLoggerTests: XCTestCase {

    var logger: DebugLogger!
    let testLogPath = "/tmp/selenechat-debug-test.log"

    override func setUp() {
        super.setUp()
        // Clean up any existing test log
        try? FileManager.default.removeItem(atPath: testLogPath)
        logger = DebugLogger(logPath: testLogPath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testLogPath)
        try? FileManager.default.removeItem(atPath: testLogPath + ".old")
        super.tearDown()
    }

    func test_log_writesToFile() {
        // Act
        logger.log(.state, "TestComponent.value: 0 → 1")
        Thread.sleep(forTimeInterval: 0.1)  // Allow async queue to flush

        // Assert
        let content = try? String(contentsOfFile: testLogPath, encoding: .utf8)
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("STATE") ?? false)
        XCTAssertTrue(content?.contains("TestComponent.value: 0 → 1") ?? false)
    }

    func test_log_includesTimestamp() {
        // Act
        logger.log(.error, "Test error message")
        Thread.sleep(forTimeInterval: 0.1)  // Allow async queue to flush

        // Assert
        let content = try? String(contentsOfFile: testLogPath, encoding: .utf8)
        XCTAssertNotNil(content)
        // Should contain date in format [YYYY-MM-DD HH:MM:SS]
        XCTAssertTrue(content?.contains("[202") ?? false)
    }

    func test_logCategory_formatsCorrectly() {
        // Act
        logger.log(.state, "state message")
        logger.log(.error, "error message")
        logger.log(.nav, "nav message")
        logger.log(.action, "action message")
        Thread.sleep(forTimeInterval: 0.1)  // Allow async queue to flush

        // Assert
        let content = try? String(contentsOfFile: testLogPath, encoding: .utf8)
        XCTAssertTrue(content?.contains("STATE") ?? false)
        XCTAssertTrue(content?.contains("ERROR") ?? false)
        XCTAssertTrue(content?.contains("NAV") ?? false)
        XCTAssertTrue(content?.contains("ACTION") ?? false)
    }

    func test_rotation_rotatesWhenExceedsMaxSize() {
        // Arrange - use tiny max size for testing
        let smallLogger = DebugLogger(logPath: testLogPath, maxSizeBytes: 100)

        // Act - write enough to exceed 100 bytes
        for i in 0..<10 {
            smallLogger.log(.state, "This is a longer message to fill up the log file quickly \(i)")
        }

        // Allow queue to flush
        Thread.sleep(forTimeInterval: 0.1)

        // Assert - backup file should exist
        let backupPath = testLogPath + ".old"
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath))

        // Cleanup
        try? FileManager.default.removeItem(atPath: backupPath)
    }

    func test_rotation_deletesOldBackup() {
        // Arrange
        let backupPath = testLogPath + ".old"
        FileManager.default.createFile(atPath: backupPath, contents: "old backup".data(using: .utf8))
        let smallLogger = DebugLogger(logPath: testLogPath, maxSizeBytes: 50)

        // Act - trigger rotation
        for i in 0..<10 {
            smallLogger.log(.state, "Message \(i) to trigger rotation")
        }

        Thread.sleep(forTimeInterval: 0.1)

        // Assert - backup exists but is new content
        let backupContent = try? String(contentsOfFile: backupPath, encoding: .utf8)
        XCTAssertNotNil(backupContent)
        XCTAssertFalse(backupContent?.contains("old backup") ?? true)

        // Cleanup
        try? FileManager.default.removeItem(atPath: backupPath)
    }
}
