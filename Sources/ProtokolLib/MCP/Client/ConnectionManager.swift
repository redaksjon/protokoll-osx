import Foundation
import OSLog

/// Manages MCP connection state and lifecycle
@available(macOS 14.0, *)
public actor ConnectionManager {
    
    // MARK: - State
    
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case failed(Error)
    }
    
    private var state: ConnectionState = .disconnected
    private let serverManager: ServerManager
    private let logger: Logger
    
    public var connectionState: ConnectionState {
        state
    }
    
    public var isConnected: Bool {
        if case .connected = state {
            return true
        }
        return false
    }
    
    // MARK: - Initialization
    
    public init(
        serverManager: ServerManager,
        logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "connection")
    ) {
        self.serverManager = serverManager
        self.logger = logger
    }
    
    // MARK: - Connection
    
    public func connect() async throws -> MCPClient {
        guard case .disconnected = state else {
            logger.warning("Already in state: \(String(describing: self.state))")
            if let client = await serverManager.getClient() {
                return client
            }
            throw ConnectionError.invalidState
        }
        
        state = .connecting
        logger.info("Connecting to MCP server")
        
        do {
            let client = try await serverManager.start()
            state = .connected
            logger.info("Connected successfully")
            return client
        } catch {
            state = .failed(error)
            logger.error("Connection failed: \(error.localizedDescription)")
            throw ConnectionError.connectionFailed(error: error)
        }
    }
    
    public func disconnect() async throws {
        logger.info("Disconnecting from MCP server")
        
        try await serverManager.stop()
        state = .disconnected
        logger.info("Disconnected successfully")
    }
    
    public func reconnect() async throws -> MCPClient {
        state = .reconnecting
        logger.info("Reconnecting to MCP server")
        
        do {
            let client = try await serverManager.restart()
            state = .connected
            logger.info("Reconnected successfully")
            return client
        } catch {
            state = .failed(error)
            logger.error("Reconnection failed: \(error.localizedDescription)")
            throw ConnectionError.reconnectionFailed(error: error)
        }
    }
}

// MARK: - Errors

public enum ConnectionError: Error, LocalizedError {
    case invalidState
    case connectionFailed(error: Error)
    case reconnectionFailed(error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidState:
            return "Invalid connection state"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .reconnectionFailed(let error):
            return "Reconnection failed: \(error.localizedDescription)"
        }
    }
}
