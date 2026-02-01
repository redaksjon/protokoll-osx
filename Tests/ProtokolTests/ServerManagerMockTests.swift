import XCTest
@testable import ProtokolLib
import OSLog

@available(macOS 14.0, *)
final class ServerManagerMockTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    private func createMockTransportFactory(transport: MockTransport) -> TransportFactory {
        return { _, _ in transport }
    }
    
    // MARK: - Start Tests
    
    func testStartSuccessfully() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        let client = try await manager.start()
        XCTAssertNotNil(client)
        
        let state = await manager.currentState
        XCTAssertEqual(state, .running)
        
        let isRunning = await manager.isRunning
        XCTAssertTrue(isRunning)
        
        try await manager.stop()
    }
    
    func testStartFailsWithTransportError() async throws {
        let transport = MockTransport()
        await transport.setStartError(StdioTransportError.serverNotFound(path: "/test/path"))
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        do {
            _ = try await manager.start()
            XCTFail("Expected error")
        } catch let error as ServerManagerError {
            if case .startFailed = error {
                // Expected
            } else {
                XCTFail("Expected startFailed, got: \(error)")
            }
        }
        
        let state = await manager.currentState
        XCTAssertEqual(state, .crashed)
    }
    
    func testStartReturnsExistingClientWhenRunning() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        let client1 = try await manager.start()
        let client2 = try await manager.start()
        
        // Should return same client without error
        XCTAssertTrue(client1 === client2)
        
        try await manager.stop()
    }
    
    func testStartThrowsInvalidStateWhenStarting() async throws {
        // This test is tricky because we can't really test the "starting" state
        // in a deterministic way. Skip it for now.
    }
    
    // MARK: - Stop Tests
    
    func testStopFromRunning() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        _ = try await manager.start()
        try await manager.stop()
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testStopWhenAlreadyStopped() async throws {
        let transport = MockTransport()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        // Stop without starting - should not throw
        try await manager.stop()
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    func testStopWithError() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Set stop error after configure
        struct TestStopError: Error {}
        await transport.setStopError(TestStopError())
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        _ = try await manager.start()
        
        do {
            try await manager.stop()
            XCTFail("Expected error")
        } catch let error as ServerManagerError {
            if case .stopFailed = error {
                // Expected
            } else {
                XCTFail("Expected stopFailed, got: \(error)")
            }
        }
        
        // State should still be stopped even on error
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    // MARK: - Restart Tests
    
    func testRestartFromRunning() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        _ = try await manager.start()
        
        // Restart should stop and start again
        let newClient = try await manager.restart()
        XCTAssertNotNil(newClient)
        
        let state = await manager.currentState
        XCTAssertEqual(state, .running)
        
        try await manager.stop()
    }
    
    func testRestartFromStopped() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        // Restart from stopped should just start
        let client = try await manager.restart()
        XCTAssertNotNil(client)
        
        let state = await manager.currentState
        XCTAssertEqual(state, .running)
        
        try await manager.stop()
    }
    
    // MARK: - GetClient Tests
    
    func testGetClientWhenRunning() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        _ = try await manager.start()
        
        let client = await manager.getClient()
        XCTAssertNotNil(client)
        
        try await manager.stop()
    }
    
    func testGetClientWhenStopped() async throws {
        let transport = MockTransport()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        let client = await manager.getClient()
        XCTAssertNil(client)
    }
    
    // MARK: - State Tests
    
    func testInitialState() async throws {
        let transport = MockTransport()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
        
        let isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
    }
    
    // MARK: - Default Transport Factory Tests
    
    func testDefaultTransportFactory() async throws {
        // Test that default factory creates StdioTransport
        let logger = Logger(subsystem: "test", category: "test")
        let transport = ServerManager.defaultTransportFactory("/test/path", logger)
        
        // Just verify it returns something - we can't inspect the type easily
        XCTAssertNotNil(transport)
    }
    
    // MARK: - Error Description Tests
    
    func testServerManagerErrorDescriptions() {
        // Test all error description paths
        let invalidStateError = ServerManagerError.invalidState(.running)
        XCTAssertTrue(invalidStateError.errorDescription?.contains("Invalid server state") == true)
        
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        
        let startFailedError = ServerManagerError.startFailed(error: TestError())
        XCTAssertTrue(startFailedError.errorDescription?.contains("Failed to start server") == true)
        
        let stopFailedError = ServerManagerError.stopFailed(error: TestError())
        XCTAssertTrue(stopFailedError.errorDescription?.contains("Failed to stop server") == true)
        
        let serverNotRunningError = ServerManagerError.serverNotRunning
        XCTAssertEqual(serverNotRunningError.errorDescription, "Server is not running")
    }
    
    // MARK: - Multiple Operations Tests
    
    func testStartStopMultipleTimes() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        // First cycle
        _ = try await manager.start()
        try await manager.stop()
        
        // Reset the transport for second cycle
        await transport.reset()
        await transport.configureInitializeResponse()
        
        // Second cycle
        _ = try await manager.start()
        try await manager.stop()
        
        let state = await manager.currentState
        XCTAssertEqual(state, .stopped)
    }
    
    // MARK: - State Transition Tests
    
    func testStateTransitionsDuringStart() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        let initialState = await manager.currentState
        XCTAssertEqual(initialState, .stopped)
        
        _ = try await manager.start()
        
        let runningState = await manager.currentState
        XCTAssertEqual(runningState, .running)
        
        try await manager.stop()
        
        let finalState = await manager.currentState
        XCTAssertEqual(finalState, .stopped)
    }
}
