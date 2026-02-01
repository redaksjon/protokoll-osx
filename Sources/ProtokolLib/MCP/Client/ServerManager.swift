import Foundation
import OSLog

/// Type alias for transport factory closure
public typealias TransportFactory = @Sendable (String, Logger) -> any MCPTransport

/// Configuration for ServerManager health monitoring
public struct ServerManagerConfig: Sendable, Equatable {
    /// Interval between health checks in nanoseconds
    public let healthCheckIntervalNs: UInt64
    /// Number of chunks to break the health check interval into (for cancellation responsiveness)
    public let healthCheckChunks: Int
    /// Maximum restart attempts before giving up
    public let maxRestartAttempts: Int
    /// Whether to enable automatic health monitoring
    public let enableHealthMonitoring: Bool
    
    public static let `default` = ServerManagerConfig(
        healthCheckIntervalNs: 10_000_000_000, // 10 seconds
        healthCheckChunks: 100,
        maxRestartAttempts: 3,
        enableHealthMonitoring: true
    )
    
    /// Configuration for fast testing with minimal delays
    public static let testing = ServerManagerConfig(
        healthCheckIntervalNs: 10_000_000, // 10ms
        healthCheckChunks: 1,
        maxRestartAttempts: 3,
        enableHealthMonitoring: false
    )
    
    public init(
        healthCheckIntervalNs: UInt64 = 10_000_000_000,
        healthCheckChunks: Int = 100,
        maxRestartAttempts: Int = 3,
        enableHealthMonitoring: Bool = true
    ) {
        self.healthCheckIntervalNs = healthCheckIntervalNs
        self.healthCheckChunks = healthCheckChunks
        self.maxRestartAttempts = maxRestartAttempts
        self.enableHealthMonitoring = enableHealthMonitoring
    }
}

/// Manages the lifecycle of the protokoll-mcp server
@available(macOS 14.0, *)
public actor ServerManager {
    
    // MARK: - Properties
    
    private let serverPath: String
    private let logger: Logger
    private let transportFactory: TransportFactory
    private let config: ServerManagerConfig
    private var transport: (any MCPTransport)?
    private var client: MCPClient?
    private var restartAttempts: Int = 0
    private var isShuttingDown: Bool = false
    private var healthMonitoringTask: Task<Void, Never>?
    
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
    
    /// Default transport factory that creates StdioTransport
    public static let defaultTransportFactory: TransportFactory = { path, logger in
        StdioTransport(serverPath: path, logger: logger)
    }
    
    public init(
        serverPath: String = NSHomeDirectory() + "/.nvm/versions/node/v24.8.0/bin/protokoll-mcp",
        logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "server"),
        transportFactory: TransportFactory? = nil,
        config: ServerManagerConfig = .default
    ) {
        self.serverPath = serverPath
        self.logger = logger
        self.transportFactory = transportFactory ?? ServerManager.defaultTransportFactory
        self.config = config
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
            // Create transport and client using factory
            let transport = transportFactory(serverPath, logger)
            let client = MCPClient(transport: transport, logger: logger)
            
            // Start client (which starts transport and initializes)
            try await client.start()
            
            // Store references
            self.transport = transport
            self.client = client
            self.state = .running
            self.restartAttempts = 0
            
            logger.info("Server started successfully")
            
            // Start health monitoring if enabled
            if config.enableHealthMonitoring {
                healthMonitoringTask = Task {
                    await monitorHealth()
                }
            }
            
            return client
        } catch {
            // Make sure health monitoring doesn't start if we failed
            healthMonitoringTask?.cancel()
            healthMonitoringTask = nil
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
        
        // Cancel health monitoring task
        healthMonitoringTask?.cancel()
        healthMonitoringTask = nil
        
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
        let chunkSleepNs = config.healthCheckIntervalNs / UInt64(max(config.healthCheckChunks, 1))
        
        while !Task.isCancelled && isRunning && !isShuttingDown {
            // Wait between health checks, but check cancellation frequently
            for _ in 0..<config.healthCheckChunks {
                guard !Task.isCancelled && isRunning && !isShuttingDown else {
                    return
                }
                try? await Task.sleep(nanoseconds: chunkSleepNs)
            }
            
            guard !Task.isCancelled, let client = client, !isShuttingDown else {
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
    
    /// Manually trigger a health check (for testing)
    public func performHealthCheck() async -> Bool {
        guard let client = client else { return false }
        return await client.isReady
    }
    
    /// Manually trigger crash handling (for testing)
    public func simulateCrash() async {
        await handleCrash()
    }
    
    /// Get current restart attempt count (for testing)
    public var currentRestartAttempts: Int {
        restartAttempts
    }
    
    /// Reset restart attempts (for testing)
    public func resetRestartAttempts() {
        restartAttempts = 0
    }
    
    // MARK: - Crash Handling
    
    private func handleCrash() async {
        logger.error("Server crashed")
        state = .crashed
        
        guard !isShuttingDown else {
            return
        }
        
        // Attempt restart if under max attempts
        guard restartAttempts < config.maxRestartAttempts else {
            logger.error("Max restart attempts reached, giving up")
            return
        }
        
        restartAttempts += 1
        logger.info("Attempting restart (\(self.restartAttempts)/\(self.config.maxRestartAttempts))")
        
        // Exponential backoff - reduced for testing config
        let delay = min(pow(2.0, Double(restartAttempts)), 30.0)
        let delayNs = config == .testing ? 10_000_000 : UInt64(delay * 1_000_000_000) // 10ms for testing
        try? await Task.sleep(nanoseconds: delayNs)
        
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
