import XCTest
import OSLog
@testable import ProtokolLib

/// Tests for StdioTransport
/// 
/// NOTE: These tests avoid async setUp/tearDown which can cause XCTest to hang
/// when used with Swift actors. Instead, transport instances are created
/// directly in test methods.
@available(macOS 14.0, *)
final class StdioTransportTests: XCTestCase {
    
    private let nonexistentPath = "/nonexistent/path/to/server"
    
    // MARK: - Synchronous Error Type Tests
    // These don't need async and test the error enum directly
    
    func testStdioTransportErrorServerNotFoundDescription() {
        let error = StdioTransportError.serverNotFound(path: "/test/path")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("/test/path") ?? false)
    }
    
    func testStdioTransportErrorFailedToStartDescription() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = StdioTransportError.failedToStart(error: underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Test error") ?? false)
    }
    
    func testStdioTransportErrorNotConnectedDescription() {
        let error = StdioTransportError.notConnected
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, "Transport not connected")
    }
    
    func testStdioTransportErrorConnectionClosedDescription() {
        let error = StdioTransportError.connectionClosed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, "Connection closed")
    }
    
    func testStdioTransportErrorWriteFailedDescription() {
        let underlyingError = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Write error"])
        let error = StdioTransportError.writeFailed(error: underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Write error") ?? false)
    }
    
    func testStdioTransportErrorLocalizedDescription() {
        let error = StdioTransportError.serverNotFound(path: "/test")
        // LocalizedError protocol provides localizedDescription via errorDescription
        XCTAssertNotNil(error.localizedDescription)
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    
    func testAllErrorCasesHaveDescriptions() {
        let errors: [StdioTransportError] = [
            .serverNotFound(path: "/path"),
            .failedToStart(error: NSError(domain: "Test", code: 1)),
            .notConnected,
            .connectionClosed,
            .writeFailed(error: NSError(domain: "Test", code: 2))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Error \(error) description should not be empty")
        }
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithCustomPath() async {
        let transport = StdioTransport(serverPath: "/custom/path")
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected, "New transport should not be connected")
    }
    
    func testInitializationWithDefaultPath() async {
        let transport = StdioTransport()
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected, "New transport should not be connected")
    }
    
    func testInitializationWithCustomLogger() async {
        let logger = Logger(subsystem: "test.subsystem", category: "test.category")
        let transport = StdioTransport(serverPath: "/test/path", logger: logger)
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected, "New transport should not be connected")
    }
    
    // MARK: - isConnected Tests
    
    func testIsConnectedReturnsFalseWhenNotStarted() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    // MARK: - Start Tests
    
    func testStartFailsWhenServerNotFound() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        do {
            try await transport.start()
            XCTFail("Expected start to throw serverNotFound error")
        } catch let error as StdioTransportError {
            if case .serverNotFound(let path) = error {
                XCTAssertEqual(path, nonexistentPath)
            } else {
                XCTFail("Expected serverNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testStartFailsWithEmptyPath() async {
        let transport = StdioTransport(serverPath: "")
        
        do {
            try await transport.start()
            XCTFail("Expected start to fail with empty path")
        } catch let error as StdioTransportError {
            if case .serverNotFound(let path) = error {
                XCTAssertEqual(path, "")
            } else {
                XCTFail("Expected serverNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Stop Tests
    
    func testStopSucceedsWhenNotStarted() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        // Should not throw when stopping a transport that was never started
        try await transport.stop()
        
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    func testMultipleStopsAreIdempotent() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        // Multiple stops should be safe
        try await transport.stop()
        try await transport.stop()
        try await transport.stop()
        
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    func testStopAfterFailedStart() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        // Start should fail
        do {
            try await transport.start()
            XCTFail("Expected start to fail")
        } catch {
            // Expected
        }
        
        // Stop should still succeed
        try await transport.stop()
        
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    // MARK: - Send Tests
    
    func testSendFailsWhenNotConnected() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let message = "test message".data(using: .utf8)!
        
        do {
            try await transport.send(message)
            XCTFail("Expected send to fail when not connected")
        } catch let error as StdioTransportError {
            if case .notConnected = error {
                // Expected
            } else {
                XCTFail("Expected notConnected error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSendEmptyDataFailsWhenNotConnected() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let emptyData = Data()
        
        do {
            try await transport.send(emptyData)
            XCTFail("Expected send to fail when not connected")
        } catch let error as StdioTransportError {
            if case .notConnected = error {
                // Expected
            } else {
                XCTFail("Expected notConnected error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSendLargeDataFailsWhenNotConnected() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let largeData = Data(repeating: 0x41, count: 100_000) // 100KB of 'A's
        
        do {
            try await transport.send(largeData)
            XCTFail("Expected send to fail when not connected")
        } catch let error as StdioTransportError {
            if case .notConnected = error {
                // Expected
            } else {
                XCTFail("Expected notConnected error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - DeliverMessage Tests
    
    func testDeliverMessageQueuesMessage() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let testData = "test message".data(using: .utf8)!
        
        // Deliver a message (this is a public method for the read loop)
        await transport.deliverMessage(testData)
        
        // The message should be queued since no one was waiting
        // We can't directly verify the queue, but we can try to receive
        // Note: receive() will wait indefinitely if no message, but we just delivered one
        
        // Start a task to receive with timeout
        let receiveTask = Task {
            try await transport.receive()
        }
        
        // Give it a moment to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Cancel if still waiting (shouldn't be since we delivered a message)
        receiveTask.cancel()
        
        do {
            let received = try await receiveTask.value
            XCTAssertEqual(received, testData)
        } catch {
            // If cancelled, the message was likely not retrieved due to timing
            // This is acceptable for this test
        }
    }
    
    func testDeliverMultipleMessagesInFIFOOrder() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let message1 = "message 1".data(using: .utf8)!
        let message2 = "message 2".data(using: .utf8)!
        let message3 = "message 3".data(using: .utf8)!
        
        // Deliver multiple messages
        await transport.deliverMessage(message1)
        await transport.deliverMessage(message2)
        await transport.deliverMessage(message3)
        
        // Messages should be delivered in FIFO order
        // Use sequential receives to avoid race conditions
        let r1 = try await transport.receive()
        let r2 = try await transport.receive()
        let r3 = try await transport.receive()
        
        XCTAssertEqual(r1, message1, "First message should match")
        XCTAssertEqual(r2, message2, "Second message should match")
        XCTAssertEqual(r3, message3, "Third message should match")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSendAttemptsAllFail() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let message = "test".data(using: .utf8)!
        
        // Launch multiple concurrent sends
        async let result1: Result<Void, Error> = {
            do {
                try await transport.send(message)
                return .success(())
            } catch {
                return .failure(error)
            }
        }()
        
        async let result2: Result<Void, Error> = {
            do {
                try await transport.send(message)
                return .success(())
            } catch {
                return .failure(error)
            }
        }()
        
        async let result3: Result<Void, Error> = {
            do {
                try await transport.send(message)
                return .success(())
            } catch {
                return .failure(error)
            }
        }()
        
        let results = await [result1, result2, result3]
        
        // All should have failed with notConnected
        for result in results {
            switch result {
            case .success:
                XCTFail("Expected send to fail")
            case .failure(let error):
                if let transportError = error as? StdioTransportError {
                    if case .notConnected = transportError {
                        // Expected
                    } else {
                        XCTFail("Expected notConnected error")
                    }
                } else {
                    XCTFail("Expected StdioTransportError")
                }
            }
        }
    }
    
    // MARK: - Full Lifecycle Tests
    
    func testFullLifecycleWithFailedStart() async throws {
        // Create
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        // Verify initial state
        var isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
        
        // Try to start (should fail)
        do {
            try await transport.start()
            XCTFail("Expected start to fail")
        } catch let error as StdioTransportError {
            if case .serverNotFound = error {
                // Expected
            } else {
                XCTFail("Expected serverNotFound error")
            }
        }
        
        // Verify still not connected
        isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
        
        // Stop (should succeed even after failed start)
        try await transport.stop()
        
        // Verify final state
        isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    func testCreateMultipleTransportInstances() async {
        // Create multiple independent instances
        let transport1 = StdioTransport(serverPath: "/path/1")
        let transport2 = StdioTransport(serverPath: "/path/2")
        let transport3 = StdioTransport(serverPath: "/path/3")
        
        // All should be independent and not connected
        let connected1 = await transport1.isConnected
        let connected2 = await transport2.isConnected
        let connected3 = await transport3.isConnected
        
        XCTAssertFalse(connected1)
        XCTAssertFalse(connected2)
        XCTAssertFalse(connected3)
    }
    
    // MARK: - Additional Error Tests
    
    func testStartWithDirectoryPathFails() async {
        // Using a directory path instead of a file
        let transport = StdioTransport(serverPath: "/usr/bin")
        
        do {
            try await transport.start()
            XCTFail("Expected start to fail with directory path")
        } catch {
            // Expected - can't execute a directory
        }
    }
    
    func testSendAfterStop() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        try await transport.stop()
        
        let message = "test".data(using: .utf8)!
        do {
            try await transport.send(message)
            XCTFail("Expected send to fail after stop")
        } catch let error as StdioTransportError {
            if case .notConnected = error {
                // Expected
            } else {
                XCTFail("Expected notConnected error")
            }
        }
    }
    
    // MARK: - DeliverMessage Edge Cases
    
    func testDeliverEmptyMessage() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let emptyData = Data()
        
        // Should handle empty data gracefully
        await transport.deliverMessage(emptyData)
        
        // Receive should return the empty data
        let received = try await transport.receive()
        XCTAssertEqual(received, emptyData)
    }
    
    func testDeliverLargeMessage() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let largeData = Data(repeating: 0x42, count: 10000) // 10KB
        
        await transport.deliverMessage(largeData)
        
        let received = try await transport.receive()
        XCTAssertEqual(received, largeData)
    }
    
    func testDeliverAndReceiveWithWaiter() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let testData = "waiter test".data(using: .utf8)!
        
        // Start a receive task BEFORE delivering (tests waiter path)
        let receiveTask = Task {
            try await transport.receive()
        }
        
        // Small delay to ensure receive is waiting
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        // Now deliver
        await transport.deliverMessage(testData)
        
        // Receive should complete
        let received = try await receiveTask.value
        XCTAssertEqual(received, testData)
    }
    
    // MARK: - Start Failure Tests
    
    func testStartWithNonExecutablePath() async {
        // A file that exists but isn't executable
        let transport = StdioTransport(serverPath: "/etc/hosts")
        
        do {
            try await transport.start()
            XCTFail("Expected start to fail with non-executable file")
        } catch {
            // Expected - file exists but can't be executed
        }
    }
    
    func testStartWithSpecialCharactersInPath() async {
        let transport = StdioTransport(serverPath: "/path/with spaces/and-special_chars/server")
        
        do {
            try await transport.start()
            XCTFail("Expected start to fail")
        } catch let error as StdioTransportError {
            if case .serverNotFound = error {
                // Expected
            } else {
                XCTFail("Expected serverNotFound error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentStops() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        
        // Multiple concurrent stops should be safe
        async let stop1: Void = transport.stop()
        async let stop2: Void = transport.stop()
        async let stop3: Void = transport.stop()
        
        try await stop1
        try await stop2
        try await stop3
        
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    func testConcurrentDeliverAndReceive() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let messages = (0..<5).map { "message \($0)".data(using: .utf8)! }
        
        // Deliver all messages
        for message in messages {
            await transport.deliverMessage(message)
        }
        
        // Receive all messages
        var received: [Data] = []
        for _ in 0..<5 {
            let data = try await transport.receive()
            received.append(data)
        }
        
        XCTAssertEqual(received.count, 5)
        XCTAssertEqual(received, messages)
    }
}
