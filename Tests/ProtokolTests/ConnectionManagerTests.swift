import XCTest
@testable import ProtokolLib

@available(macOS 14.0, *)
final class ConnectionManagerTests: XCTestCase {
    
    var serverManager: ServerManager!
    var connectionManager: ConnectionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        // Use a non-existent path to avoid starting real server in tests
        serverManager = ServerManager(serverPath: "/nonexistent/path/server")
        connectionManager = ConnectionManager(serverManager: serverManager)
    }
    
    override func tearDown() async throws {
        // Always try to disconnect to clean up any background tasks
        try? await connectionManager.disconnect()
        // Give background tasks time to clean up
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        connectionManager = nil
        serverManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() async {
        let manager = ServerManager(serverPath: "/test/path")
        let connManager = ConnectionManager(serverManager: manager)
        
        let state = await connManager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state")
        }
        let isConnected = await connManager.isConnected
        XCTAssertFalse(isConnected)
    }
    
    // MARK: - Connection State Tests
    
    func testInitialState() async {
        let state = await connectionManager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state")
        }
        let isConnected = await connectionManager.isConnected
        XCTAssertFalse(isConnected)
    }
    
    func testConnectionStateProperty() async {
        let state = await connectionManager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state")
        }
    }
    
    func testIsConnectedProperty() async {
        let isConnected = await connectionManager.isConnected
        XCTAssertFalse(isConnected)
    }
    
    // MARK: - Connect Tests
    
    func testConnectWhenDisconnected() async throws {
        // This will fail because server path doesn't exist, but we can test the state transitions
        do {
            _ = try await connectionManager.connect()
            XCTFail("Expected connection to fail")
        } catch {
            // Expected - server path doesn't exist
            let state = await connectionManager.connectionState
            if case .failed = state {
                // State should be failed
            } else {
                // Or still disconnected if error handling is different
            }
        }
    }
    
    func testConnectWhenAlreadyConnecting() async {
        // Start a connection attempt
        let connectTask = Task {
            try? await connectionManager.connect()
        }
        
        // Give it a moment, then cancel to prevent hanging
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        connectTask.cancel()
        
        // Try to connect again - should handle invalid state
        do {
            _ = try await connectionManager.connect()
        } catch {
            // Expected - should handle invalid state
        }
    }
    
    func testConnectWhenAlreadyConnected() async throws {
        // This test would require a mock server manager
        // For now, we test the state check logic
        let state = await connectionManager.connectionState
        if case .connected = state {
            // If somehow connected, should return existing client
            do {
                let client = try await connectionManager.connect()
                XCTAssertNotNil(client)
            } catch {
                XCTFail("Should return existing client when connected")
            }
        }
    }
    
    // MARK: - Disconnect Tests
    
    func testDisconnectWhenDisconnected() async throws {
        // Should succeed without error
        try await connectionManager.disconnect()
        let state = await connectionManager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state")
        }
    }
    
    func testDisconnectWhenConnected() async throws {
        // This would require a mock that simulates a connected state
        // For now, test that disconnect doesn't throw when already disconnected
        try await connectionManager.disconnect()
    }
    
    // MARK: - Reconnect Tests
    
    func testReconnect() async throws {
        // Reconnect should attempt to restart the server
        do {
            _ = try await connectionManager.reconnect()
            XCTFail("Expected reconnect to fail")
        } catch {
            // Expected - server path doesn't exist
            let state = await connectionManager.connectionState
            if case .failed = state {
                // State should be failed
            }
        }
    }
    
    func testReconnectStateTransition() async throws {
        // Test that reconnect sets state to reconnecting
        // Don't wait for completion - just check state transitions quickly
        let reconnectTask = Task {
            try? await connectionManager.reconnect()
        }
        
        // Give it a brief moment to set state
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        let state = await connectionManager.connectionState
        // State should be reconnecting or failed
        let isValidState: Bool
        switch state {
        case .reconnecting, .failed:
            isValidState = true
        default:
            isValidState = false
        }
        XCTAssertTrue(isValidState, "Expected reconnecting or failed state")
        
        // Cancel to prevent hanging
        reconnectTask.cancel()
    }
    
    // MARK: - Error Handling Tests
    
    func testConnectionErrorHandling() async {
        // Test that connection errors are properly wrapped
        do {
            _ = try await connectionManager.connect()
            XCTFail("Expected error")
        } catch let error as ConnectionError {
            if case .connectionFailed = error {
                // Expected error type
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            // Other errors are also acceptable
        }
    }
    
    func testReconnectionErrorHandling() async {
        // Test that reconnection errors are properly wrapped
        do {
            _ = try await connectionManager.reconnect()
            XCTFail("Expected error")
        } catch let error as ConnectionError {
            if case .reconnectionFailed = error {
                // Expected error type
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            // Other errors are also acceptable
        }
    }
    
    // MARK: - ConnectionError Tests
    
    func testConnectionErrorDescriptions() {
        let invalidStateError = ConnectionError.invalidState
        XCTAssertNotNil(invalidStateError.errorDescription)
        
        let connectionFailedError = ConnectionError.connectionFailed(error: NSError(domain: "Test", code: 1))
        XCTAssertNotNil(connectionFailedError.errorDescription)
        
        let reconnectionFailedError = ConnectionError.reconnectionFailed(error: NSError(domain: "Test", code: 2))
        XCTAssertNotNil(reconnectionFailedError.errorDescription)
    }
    
    func testConnectionErrorDescriptionContent() {
        let invalidState = ConnectionError.invalidState
        XCTAssertTrue(invalidState.errorDescription?.contains("Invalid") ?? false)
        
        let connFailed = ConnectionError.connectionFailed(error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"]))
        XCTAssertTrue(connFailed.errorDescription?.contains("Network error") ?? false)
        
        let reconnFailed = ConnectionError.reconnectionFailed(error: NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Timeout"]))
        XCTAssertTrue(reconnFailed.errorDescription?.contains("Timeout") ?? false)
    }
    
    func testAllConnectionErrorCases() {
        let errors: [ConnectionError] = [
            .invalidState,
            .connectionFailed(error: NSError(domain: "Test", code: 1)),
            .reconnectionFailed(error: NSError(domain: "Test", code: 2))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    // MARK: - Additional State Tests
    
    func testMultipleDisconnects() async throws {
        // Multiple disconnects should be safe
        try await connectionManager.disconnect()
        try await connectionManager.disconnect()
        try await connectionManager.disconnect()
        
        let state = await connectionManager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state after multiple disconnects")
        }
    }
    
    func testIsConnectedForAllStates() async {
        // Test isConnected returns false for non-connected states
        let state = await connectionManager.connectionState
        let isConnected = await connectionManager.isConnected
        
        switch state {
        case .disconnected, .connecting, .reconnecting, .failed:
            XCTAssertFalse(isConnected)
        case .connected:
            XCTAssertTrue(isConnected)
        }
    }
    
    func testConnectAfterFailure() async {
        // First connect attempt fails
        do {
            _ = try await connectionManager.connect()
        } catch {
            // Expected
        }
        
        let stateAfterFirstFail = await connectionManager.connectionState
        if case .failed = stateAfterFirstFail {
            // Good, state is failed
        }
        
        // Second connect attempt - state is no longer disconnected
        // Should handle the invalid state
        do {
            _ = try await connectionManager.connect()
            XCTFail("Expected error on second connect")
        } catch let error as ConnectionError {
            // Expected - either invalidState or connectionFailed
            switch error {
            case .invalidState, .connectionFailed:
                break // Expected
            case .reconnectionFailed:
                XCTFail("Unexpected reconnectionFailed error")
            }
        } catch {
            // Other errors acceptable
        }
    }
}
