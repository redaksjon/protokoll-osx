import XCTest
import OSLog
@testable import ProtokolLib

/// Tests for ServerManager
///
/// NOTE: These tests avoid async setUp/tearDown which can cause XCTest to hang
/// when used with Swift actors. Instead, ServerManager instances are created
/// directly in test methods.
@available(macOS 14.0, *)
final class ServerManagerTests: XCTestCase {
    
    private let nonexistentPath = "/nonexistent/path/server"
    
    // MARK: - Synchronous Error Type Tests
    
    func testServerManagerErrorInvalidStateDescription() {
        let error = ServerManagerError.invalidState(.stopped)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("stopped") ?? false)
    }
    
    func testServerManagerErrorStartFailedDescription() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Start error"])
        let error = ServerManagerError.startFailed(error: underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Start error") ?? false)
    }
    
    func testServerManagerErrorStopFailedDescription() {
        let underlyingError = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Stop error"])
        let error = ServerManagerError.stopFailed(error: underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Stop error") ?? false)
    }
    
    func testServerManagerErrorServerNotRunningDescription() {
        let error = ServerManagerError.serverNotRunning
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, "Server is not running")
    }
    
    func testAllErrorCasesHaveDescriptions() {
        let errors: [ServerManagerError] = [
            .invalidState(.stopped),
            .invalidState(.starting),
            .invalidState(.running),
            .invalidState(.shuttingDown),
            .invalidState(.crashed),
            .startFailed(error: NSError(domain: "Test", code: 1)),
            .stopFailed(error: NSError(domain: "Test", code: 2)),
            .serverNotRunning
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Error \(error) description should not be empty")
        }
    }
    
    func testServerStateValues() {
        // ServerState is used in error messages, test all values exist
        let states: [ServerManager.ServerState] = [.stopped, .starting, .running, .shuttingDown, .crashed]
        XCTAssertEqual(states.count, 5)
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithCustomPath() async {
        let manager = ServerManager(serverPath: "/custom/path")
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
        let isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
    }
    
    func testInitializationWithDefaultPath() async {
        let manager = ServerManager()
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testInitialStateIsStopped() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testIsRunningInitiallyFalse() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        let isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
    }
    
    // MARK: - Start Tests
    
    func testStartFailsWithNonexistentPath() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        do {
            _ = try await manager.start()
            XCTFail("Expected start to fail with nonexistent path")
        } catch let error as ServerManagerError {
            if case .startFailed = error {
                // Expected
                let state = await manager.currentState
                XCTAssertEqual(state, .crashed)
            } else {
                XCTFail("Expected startFailed error, got: \(error)")
            }
        } catch {
            // Other errors acceptable
        }
    }
    
    func testStartSetsStateToCrashedOnFailure() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        let state = await manager.currentState
        XCTAssertEqual(state, .crashed)
    }
    
    func testStartFromCrashedState() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // First start fails
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        let state1 = await manager.currentState
        XCTAssertEqual(state1, .crashed)
        
        // Second start from crashed should also fail
        do {
            _ = try await manager.start()
            XCTFail("Expected second start to fail")
        } catch {
            // Expected
        }
        
        let state2 = await manager.currentState
        XCTAssertEqual(state2, .crashed)
    }
    
    // MARK: - Stop Tests
    
    func testStopWhenStopped() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Should succeed without error
        try await manager.stop()
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testMultipleStopsAreIdempotent() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        try await manager.stop()
        try await manager.stop()
        try await manager.stop()
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testStopCleansUpClient() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        try await manager.stop()
        
        let client = await manager.getClient()
        XCTAssertNil(client)
    }
    
    func testStopAfterFailedStart() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Start fails
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        // Stop should still work
        try await manager.stop()
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    // MARK: - Restart Tests
    
    func testRestartFromStopped() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        do {
            _ = try await manager.restart()
            XCTFail("Expected restart to fail")
        } catch {
            // Expected - server path doesn't exist
        }
    }
    
    func testRestartAfterFailedStart() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // First start fails
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        // Restart should also fail
        do {
            _ = try await manager.restart()
            XCTFail("Expected restart to fail")
        } catch {
            // Expected
        }
    }
    
    // MARK: - GetClient Tests
    
    func testGetClientWhenStopped() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        let client = await manager.getClient()
        XCTAssertNil(client)
    }
    
    func testGetClientAfterFailedStart() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        let client = await manager.getClient()
        XCTAssertNil(client)
    }
    
    // MARK: - State Property Tests
    
    func testCurrentStateProperty() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Initial state
        var state = await manager.currentState
        XCTAssertEqual(state, .stopped)
        
        // After failed start
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        state = await manager.currentState
        XCTAssertEqual(state, .crashed)
        
        // After stop
        try? await manager.stop()
        state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testIsRunningProperty() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        var isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
        
        // After failed start
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        isRunning = await manager.isRunning
        XCTAssertFalse(isRunning) // Should still be false after crash
    }
    
    // MARK: - Full Lifecycle Tests
    
    func testFullLifecycleWithFailedStart() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Initial state
        var state = await manager.currentState
        XCTAssertEqual(state, .stopped)
        var isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
        
        // Try to start (should fail)
        do {
            _ = try await manager.start()
            XCTFail("Expected start to fail")
        } catch {
            // Expected
        }
        
        // After failed start
        state = await manager.currentState
        XCTAssertEqual(state, .crashed)
        isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
        
        // Stop
        try await manager.stop()
        
        // Final state
        state = await manager.currentState
        XCTAssertEqual(state, .stopped)
        isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
        
        let client = await manager.getClient()
        XCTAssertNil(client)
    }
    
    func testCreateMultipleManagerInstances() async {
        let manager1 = ServerManager(serverPath: "/path/1")
        let manager2 = ServerManager(serverPath: "/path/2")
        let manager3 = ServerManager(serverPath: "/path/3")
        
        // All should be independent and stopped
        let state1 = await manager1.currentState
        let state2 = await manager2.currentState
        let state3 = await manager3.currentState
        
        XCTAssertEqual(state1, .stopped)
        XCTAssertEqual(state2, .stopped)
        XCTAssertEqual(state3, .stopped)
    }
    
    // MARK: - Concurrent Stop Tests
    
    func testConcurrentStopsAreHandled() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Launch concurrent stops
        async let stop1: Void = manager.stop()
        async let stop2: Void = manager.stop()
        async let stop3: Void = manager.stop()
        
        try await stop1
        try await stop2
        try await stop3
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    // MARK: - Additional State Tests
    
    func testAllServerStates() {
        // Verify all states are distinct
        let states: [ServerManager.ServerState] = [
            .stopped,
            .starting,
            .running,
            .shuttingDown,
            .crashed
        ]
        
        // Each state should be unique
        for (i, state1) in states.enumerated() {
            for (j, state2) in states.enumerated() {
                if i == j {
                    XCTAssertTrue(state1 == state2)
                } else {
                    XCTAssertFalse(state1 == state2)
                }
            }
        }
    }
    
    // MARK: - Error Description Tests
    
    func testInvalidStateErrorForAllStates() {
        let states: [ServerManager.ServerState] = [
            .stopped,
            .starting,
            .running,
            .shuttingDown,
            .crashed
        ]
        
        for state in states {
            let error = ServerManagerError.invalidState(state)
            XCTAssertNotNil(error.errorDescription)
            // Description should mention the state
            XCTAssertTrue(error.errorDescription?.lowercased().contains("\(state)".lowercased()) ?? false)
        }
    }
    
    func testStartFailedErrorPreservesUnderlyingError() {
        let underlying = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Custom error message"])
        let error = ServerManagerError.startFailed(error: underlying)
        
        XCTAssertTrue(error.errorDescription?.contains("Custom error message") ?? false)
    }
    
    func testStopFailedErrorPreservesUnderlyingError() {
        let underlying = NSError(domain: "TestDomain", code: 99, userInfo: [NSLocalizedDescriptionKey: "Stop failed message"])
        let error = ServerManagerError.stopFailed(error: underlying)
        
        XCTAssertTrue(error.errorDescription?.contains("Stop failed message") ?? false)
    }
    
    // MARK: - Multiple Start Attempts
    
    func testMultipleStartAttemptsAfterCrash() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Multiple start attempts should all fail and maintain crashed state
        for _ in 0..<3 {
            do {
                _ = try await manager.start()
                XCTFail("Expected start to fail")
            } catch {
                // Expected
            }
            
            let state = await manager.currentState
            XCTAssertEqual(state, .crashed)
        }
    }
    
    // MARK: - Restart Variations
    
    func testRestartFromCrashedState() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // First start to crash
        do {
            _ = try await manager.start()
        } catch {
            // Expected
        }
        
        let state1 = await manager.currentState
        XCTAssertEqual(state1, .crashed)
        
        // Restart from crashed state
        do {
            _ = try await manager.restart()
            XCTFail("Expected restart to fail")
        } catch {
            // Expected - still can't find server
        }
    }
    
    func testRestartIncludesDelay() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        let startTime = Date()
        
        do {
            _ = try await manager.restart()
        } catch {
            // Expected
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        // Restart includes a 1 second delay
        XCTAssertGreaterThan(elapsed, 0.9) // Allow some tolerance
    }
    
    // MARK: - Client Access Tests
    
    func testGetClientMultipleTimes() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Multiple calls should all return nil
        let client1 = await manager.getClient()
        let client2 = await manager.getClient()
        let client3 = await manager.getClient()
        
        XCTAssertNil(client1)
        XCTAssertNil(client2)
        XCTAssertNil(client3)
    }
    
    func testGetClientAfterMultipleStops() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        try await manager.stop()
        let client1 = await manager.getClient()
        
        try await manager.stop()
        let client2 = await manager.getClient()
        
        XCTAssertNil(client1)
        XCTAssertNil(client2)
    }
    
    // MARK: - Initialization with Logger
    
    func testInitializationWithCustomLogger() async {
        let logger = Logger(subsystem: "test.subsystem", category: "test.category")
        let manager = ServerManager(serverPath: nonexistentPath, logger: logger)
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    // MARK: - Crash Recovery Tests
    
    func testStateAfterCrash() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Start fails, state should be crashed
        do {
            _ = try await manager.start()
        } catch { /* Expected */ }
        
        let state = await manager.currentState
        XCTAssertEqual(state, .crashed)
        
        // isRunning should be false
        let isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
    }
    
    func testRestartFromCrashedResetsToCrashed() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // First crash
        do {
            _ = try await manager.start()
        } catch { /* Expected */ }
        
        var state = await manager.currentState
        XCTAssertEqual(state, .crashed)
        
        // Restart attempt
        do {
            _ = try await manager.restart()
        } catch { /* Expected */ }
        
        // Should still be crashed
        state = await manager.currentState
        XCTAssertEqual(state, .crashed)
    }
    
    // MARK: - Concurrent Start Tests
    
    func testConcurrentStartAttempts() async {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Launch concurrent starts
        async let start1 = Task {
            do {
                _ = try await manager.start()
            } catch { /* Expected */ }
        }
        
        async let start2 = Task {
            do {
                _ = try await manager.start()
            } catch { /* Expected */ }
        }
        
        await start1.value
        await start2.value
        
        // Final state should be consistent
        let state = await manager.currentState
        // Could be crashed or stopped depending on timing
        let validState = (state == .crashed || state == .stopped)
        XCTAssertTrue(validState, "Expected crashed or stopped, got \(state)")
    }
    
    // MARK: - Full Workflow Tests
    
    func testStartStopStartCycle() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Cycle 1: Start (fail) -> Stop
        do {
            _ = try await manager.start()
        } catch { /* Expected */ }
        
        try await manager.stop()
        var state = await manager.currentState
        XCTAssertEqual(state, .stopped)
        
        // Cycle 2: Start (fail) -> Stop
        do {
            _ = try await manager.start()
        } catch { /* Expected */ }
        
        try await manager.stop()
        state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testStopFromCrashedState() async throws {
        let manager = ServerManager(serverPath: nonexistentPath)
        
        // Get to crashed state
        do {
            _ = try await manager.start()
        } catch { /* Expected */ }
        
        var state = await manager.currentState
        XCTAssertEqual(state, .crashed)
        
        // Stop should reset to stopped
        try await manager.stop()
        state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    // MARK: - Error Description Validation
    
    func testErrorDescriptionsContainUsefulInfo() {
        // invalidState should mention the state
        for state: ServerManager.ServerState in [.stopped, .starting, .running, .shuttingDown, .crashed] {
            let error = ServerManagerError.invalidState(state)
            let desc = error.errorDescription ?? ""
            XCTAssertFalse(desc.isEmpty)
        }
        
        // startFailed should mention the underlying error
        let startError = ServerManagerError.startFailed(error: NSError(domain: "Test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Server unavailable"]))
        XCTAssertTrue(startError.errorDescription?.contains("Server unavailable") ?? false)
        
        // stopFailed should mention the underlying error
        let stopError = ServerManagerError.stopFailed(error: NSError(domain: "Test", code: 456, userInfo: [NSLocalizedDescriptionKey: "Cleanup failed"]))
        XCTAssertTrue(stopError.errorDescription?.contains("Cleanup failed") ?? false)
        
        // serverNotRunning should have meaningful message
        let notRunning = ServerManagerError.serverNotRunning
        XCTAssertTrue(notRunning.errorDescription?.contains("not running") ?? false)
    }
}
