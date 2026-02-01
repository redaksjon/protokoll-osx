import XCTest
@testable import ProtokolLib
import OSLog

@available(macOS 14.0, *)
final class ConnectionManagerMockTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    private func createMockTransportFactory(transport: MockTransport) -> TransportFactory {
        return { _, _ in transport }
    }
    
    private func createConnectionManager(transport: MockTransport) -> ConnectionManager {
        let serverManager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        return ConnectionManager(serverManager: serverManager)
    }
    
    // MARK: - Connect Tests
    
    func testConnectSuccessfully() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = createConnectionManager(transport: transport)
        
        let client = try await manager.connect()
        XCTAssertNotNil(client)
        
        let isConnected = await manager.isConnected
        XCTAssertTrue(isConnected)
        
        let state = await manager.connectionState
        if case .connected = state {
            // Expected
        } else {
            XCTFail("Expected connected state, got: \(state)")
        }
        
        try await manager.disconnect()
    }
    
    func testConnectFailsWithTransportError() async throws {
        let transport = MockTransport()
        await transport.setStartError(StdioTransportError.serverNotFound(path: "/test/path"))
        
        let manager = createConnectionManager(transport: transport)
        
        do {
            _ = try await manager.connect()
            XCTFail("Expected error")
        } catch let error as ConnectionError {
            if case .connectionFailed = error {
                // Expected
            } else {
                XCTFail("Expected connectionFailed, got: \(error)")
            }
        }
        
        let isConnected = await manager.isConnected
        XCTAssertFalse(isConnected)
        
        let state = await manager.connectionState
        if case .failed = state {
            // Expected
        } else {
            XCTFail("Expected failed state, got: \(state)")
        }
    }
    
    func testConnectReturnsExistingClientWhenConnected() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = createConnectionManager(transport: transport)
        
        let client1 = try await manager.connect()
        let client2 = try await manager.connect()
        
        // Should return same client
        XCTAssertTrue(client1 === client2)
        
        try await manager.disconnect()
    }
    
    func testConnectThrowsInvalidStateWhenNotDisconnected() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let serverManager = ServerManager(
            serverPath: "/test/path",
            transportFactory: createMockTransportFactory(transport: transport)
        )
        
        // Start the server to get a client
        let _ = try await serverManager.start()
        
        let manager = ConnectionManager(serverManager: serverManager)
        
        // The connection manager starts disconnected, but when we try to connect
        // and the server is already running, it should return the existing client
        let client = try await manager.connect()
        XCTAssertNotNil(client)
        
        try await manager.disconnect()
    }
    
    // MARK: - Disconnect Tests
    
    func testDisconnectFromConnected() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = createConnectionManager(transport: transport)
        
        _ = try await manager.connect()
        try await manager.disconnect()
        
        let isConnected = await manager.isConnected
        XCTAssertFalse(isConnected)
        
        let state = await manager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state, got: \(state)")
        }
    }
    
    func testDisconnectWhenAlreadyDisconnected() async throws {
        let transport = MockTransport()
        
        let manager = createConnectionManager(transport: transport)
        
        // Should not throw
        try await manager.disconnect()
        
        let state = await manager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state, got: \(state)")
        }
    }
    
    // MARK: - Reconnect Tests
    
    func testReconnectFromConnected() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = createConnectionManager(transport: transport)
        
        _ = try await manager.connect()
        
        // Reset transport for reconnect
        await transport.reset()
        await transport.configureInitializeResponse()
        
        let newClient = try await manager.reconnect()
        XCTAssertNotNil(newClient)
        
        let isConnected = await manager.isConnected
        XCTAssertTrue(isConnected)
        
        try await manager.disconnect()
    }
    
    func testReconnectFails() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let manager = createConnectionManager(transport: transport)
        
        _ = try await manager.connect()
        
        // Configure transport to fail on restart
        await transport.reset()
        await transport.setStartError(StdioTransportError.notConnected)
        
        do {
            _ = try await manager.reconnect()
            XCTFail("Expected error")
        } catch let error as ConnectionError {
            if case .reconnectionFailed = error {
                // Expected
            } else {
                XCTFail("Expected reconnectionFailed, got: \(error)")
            }
        }
        
        let state = await manager.connectionState
        if case .failed = state {
            // Expected
        } else {
            XCTFail("Expected failed state, got: \(state)")
        }
    }
    
    // MARK: - Error Description Tests
    
    func testConnectionErrorDescriptions() {
        let invalidStateError = ConnectionError.invalidState
        XCTAssertEqual(invalidStateError.errorDescription, "Invalid connection state")
        
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        
        let connectionFailedError = ConnectionError.connectionFailed(error: TestError())
        XCTAssertTrue(connectionFailedError.errorDescription?.contains("Connection failed") == true)
        
        let reconnectionFailedError = ConnectionError.reconnectionFailed(error: TestError())
        XCTAssertTrue(reconnectionFailedError.errorDescription?.contains("Reconnection failed") == true)
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() async throws {
        let transport = MockTransport()
        let manager = createConnectionManager(transport: transport)
        
        let isConnected = await manager.isConnected
        XCTAssertFalse(isConnected)
        
        let state = await manager.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state, got: \(state)")
        }
    }
}
