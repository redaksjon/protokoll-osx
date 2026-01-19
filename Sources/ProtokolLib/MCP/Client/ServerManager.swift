import Foundation
import OSLog

/// Manages the lifecycle of the protokoll-mcp server
@available(macOS 14.0, *)
public actor ServerManager {
    
    // MARK: - Properties
    
    private let serverPath: String
    private let logger: Logger
    private var transport: StdioTransport?
    private var client: MCPClient?
    private var restartAttempts: Int = 0
    private let maxRestartAttempts: Int = 3
    private var isShuttingDown: Bool = false
    
    // MARK: - State
    
    public enum ServerState {
        case stopped
        case starting
        case running
        case crashed
        case shuttingDown
    }
    
    private var state: ServerState = .stopped
    
    public var currentState: ServerState {
        state
    }
    
    public var isRunning: Bool {
        state == .running
    }
    
    // MARK: - Initialization
    
    public init(
        serverPath: String = NSHomeDirectory() + "/.nvm/versions/node/v24.8.0/bin/protokoll-mcp",
        logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "server")
    ) {
        self.serverPath = serverPath
        self.logger = logger
    }
    
    // MARK: - Lifecycle
    
    /// Start the server and initialize the client
    public func start() async throws -> MCPClient {
        guard state == .stopped || state == .crashed else {
            logger.warning("Server already in state: \(String(describing: self.state))")
            if let client = client {
                return client
            }
            throw ServerManagerError.invalidState(state)
        }
        
        state = .starting
        logger.info("Starting server")
        
        do {
            // Create transport and client
            let transport = StdioTransport(serverPath: serverPath, logger: logger)
            let client = MCPClient(transport: transport, logger: logger)
            
            // Start client (which starts transport and initializes)
            try await client.start()
            
            // Store references
            self.transport = transport
            self.client = client
            self.state = .running
            self.restartAttempts = 0
            
            logger.info("Server started successfully")
            
            // Start health monitoring
            Task {
                await monitorHealth()
            }
            
            return client
        } catch {
            state = .crashed
            logger.error("Failed to start server: \(error.localizedDescription)")
            throw ServerManagerError.startFailed(error: error)
        }
    }
    
    /// Stop the server
    public func stop() async throws {
        guard state != .stopped else {
            return
        }
        
        isShuttingDown = true
        state = .shuttingDown
        logger.info("Stopping server")
        
        do {
            try await client?.stop()
            transport = nil
            client = nil
            state = .stopped
            logger.info("Server stopped successfully")
        } catch {
            logger.error("Error stopping server: \(error.localizedDescription)")
            state = .stopped
            throw ServerManagerError.stopFailed(error: error)
        }
    }
    
    /// Restart the server
    public func restart() async throws -> MCPClient {
        logger.info("Restarting server")
        
        if state != .stopped {
            try await stop()
        }
        
        // Wait before restart
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return try await start()
    }
    
    // MARK: - Health Monitoring
    
    private func monitorHealth() async {
        while isRunning && !isShuttingDown {
            // Wait 10 seconds between health checks
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            
            guard let client = client, !isShuttingDown else {
                break
            }
            
            // Check if client is still ready
            let ready = await client.isReady
            if !ready {
                logger.warning("Server health check failed")
                await handleCrash()
                break
            }
        }
    }
    
    // MARK: - Crash Handling
    
    private func handleCrash() async {
        logger.error("Server crashed")
        state = .crashed
        
        guard !isShuttingDown else {
            return
        }
        
        // Attempt restart if under max attempts
        guard restartAttempts < maxRestartAttempts else {
            logger.error("Max restart attempts reached, giving up")
            return
        }
        
        restartAttempts += 1
        logger.info("Attempting restart (\(self.restartAttempts)/\(self.maxRestartAttempts))")
        
        // Exponential backoff
        let delay = min(pow(2.0, Double(restartAttempts)), 30.0) // Max 30s
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            _ = try await restart()
            logger.info("Server restarted successfully")
        } catch {
            logger.error("Restart failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Client Access
    
    /// Get the current client (if running)
    public func getClient() -> MCPClient? {
        client
    }
}

// MARK: - Errors

public enum ServerManagerError: Error, LocalizedError {
    case invalidState(ServerManager.ServerState)
    case startFailed(error: Error)
    case stopFailed(error: Error)
    case serverNotRunning
    
    public var errorDescription: String? {
        switch self {
        case .invalidState(let state):
            return "Invalid server state: \(state)"
        case .startFailed(let error):
            return "Failed to start server: \(error.localizedDescription)"
        case .stopFailed(let error):
            return "Failed to stop server: \(error.localizedDescription)"
        case .serverNotRunning:
            return "Server is not running"
        }
    }
}
