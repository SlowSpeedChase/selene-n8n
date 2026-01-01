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
}
