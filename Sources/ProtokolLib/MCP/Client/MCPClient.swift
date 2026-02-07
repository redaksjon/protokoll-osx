import Foundation
import OSLog

/// Main MCP client for communicating with protokoll-mcp server
@available(macOS 14.0, *)
public actor MCPClient {
    
    // MARK: - Properties
    
    private let transport: any MCPTransport
    private let logger: Logger
    private var nextRequestId: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]
    private var isInitialized = false
    private var serverCapabilities: ServerCapabilities?
    private var receiveTask: Task<Void, Never>?
    /// When set, each request/response is logged here for debugging (one line per event).
    private var debugLogHandler: (@Sendable (String) -> Void)?
    
    // MARK: - Initialization
    
    public init(transport: any MCPTransport, logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "client")) {
        self.transport = transport
        self.logger = logger
    }
    
    /// Set a handler to receive one-line debug log entries (request/response summary). Call from main app to capture MCP traffic.
    public func setDebugLogHandler(_ handler: (@Sendable (String) -> Void)?) {
        self.debugLogHandler = handler
    }
    
    private func debugLog(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date()).split(separator: "T").last.map(String.init) ?? ""
        let formatted = "[\(timestamp)] \(line)"
        logger.debug("MCP \(line)")
        debugLogHandler?(formatted)
    }
    
    // MARK: - Lifecycle
    
    /// Start the client and initialize the MCP connection
    public func start() async throws {
        logger.info("Starting MCP client")
        try await transport.start()
        
        // Start background task for receiving responses
        receiveTask = Task {
            await receiveLoop()
        }
        
        try await initialize()
        logger.info("MCP client started successfully")
    }
    
    /// Stop the client
    public func stop() async throws {
        logger.info("Stopping MCP client")
        
        // Cancel receive loop
        receiveTask?.cancel()
        receiveTask = nil
        
        // Cancel all pending requests
        for continuation in pendingRequests.values {
            continuation.resume(throwing: MCPClientError.clientStopped)
        }
        pendingRequests.removeAll()
        
        try await transport.stop()
        isInitialized = false
        logger.info("MCP client stopped")
    }
    
    /// Check if client is ready for requests
    public var isReady: Bool {
        get async {
            let connected = await transport.isConnected
            return isInitialized && connected
        }
    }
    
    // MARK: - Initialize
    
    private func initialize() async throws {
        logger.info("Initializing MCP connection")
        
        let initRequest = MCPInitializeRequest(
            protocolVersion: "2024-11-05",
            capabilities: ClientCapabilities(roots: nil, sampling: nil),
            clientInfo: ClientInfo(
                name: "Protokoll macOS",
                version: "1.0.0"
            )
        )
        
        // Use sendRequestWithRetry directly with maxAttempts=1 to avoid infinite recursion
        let response: MCPInitializeResponse = try await sendRequestWithRetry(
            method: "initialize",
            params: initRequest,
            attempt: 1,
            maxAttempts: 1  // Don't retry initialize requests
        )
        
        serverCapabilities = response.capabilities
        isInitialized = true
        
        logger.info("MCP initialized with server: \(response.serverInfo.name) v\(response.serverInfo.version)")
    }
    
    // MARK: - Request/Response
    
    /// Send a request and wait for response with automatic retry on recoverable errors
    public func sendRequest<T: Decodable>(
        method: String,
        params: (any Encodable)? = nil
    ) async throws -> T {
        return try await sendRequestWithRetry(method: method, params: params, attempt: 1)
    }
    
    /// Internal method that implements retry logic
    private func sendRequestWithRetry<T: Decodable>(
        method: String,
        params: (any Encodable)?,
        attempt: Int,
        maxAttempts: Int = 3
    ) async throws -> T {
        guard isInitialized || method == "initialize" else {
            throw MCPClientError.notInitialized
        }
        
        let requestId = nextRequestId
        nextRequestId += 1
        
        // Encode params to AnyCodable if provided
        let anyParams: AnyCodable?
        if let params = params {
            let data = try JSONEncoder().encode(params)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                anyParams = AnyCodable(dict)
            } else {
                anyParams = nil
            }
        } else {
            anyParams = nil
        }
        
        let request = JSONRPCRequest(
            id: requestId,
            method: method,
            params: anyParams
        )
        
        logger.info("Sending request: \(method) (id: \(requestId), attempt: \(attempt)/\(maxAttempts))")
        
        // Encode and send request
        let requestData = try JSONEncoder().encode(request)
        logger.debug("Request data: \(requestData.count) bytes")
        debugLog("→ \(method) id:\(requestId) attempt:\(attempt) \(requestData.count) bytes")
        
        do {
            // Register the pending request BEFORE sending, so the receive loop can dispatch
            // the response even if it arrives immediately (e.g. Streamable HTTP where the
            // response is queued synchronously by send()).
            let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONRPCResponse, Error>) in
                self.pendingRequests[requestId] = continuation
                logger.debug("Registered pending request \(requestId)")
                Task {
                    do {
                        try await self.transport.send(requestData)
                        self.logger.debug("Request sent for id \(requestId)")
                    } catch {
                        // Remove pending and fail the continuation
                        if let cont = self.pendingRequests.removeValue(forKey: requestId) {
                            cont.resume(throwing: error)
                        }
                    }
                }
            }
            
            logger.debug("Response received for request \(requestId)")
            
            // Handle error response
            if let error = response.error {
                logger.error("Request failed: \(error.message)")
                debugLog("← \(method) id:\(requestId) error \(error.code): \(error.message)")
                
                // Check if this is a recoverable error that should trigger retry
                if attempt < maxAttempts && isRecoverableError(code: error.code, message: error.message) {
                    let delay = exponentialBackoff(attempt: attempt)
                    logger.warning("Recoverable error, retrying after \(delay)s...")
                    debugLog("⟳ Retry \(method) after \(delay)s (attempt \(attempt + 1)/\(maxAttempts))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    // If session error, try to reinitialize
                    if error.message.localizedCaseInsensitiveContains("session") {
                        logger.info("Session error detected, reinitializing...")
                        try await reinitialize()
                    }
                    
                    return try await sendRequestWithRetry(method: method, params: params, attempt: attempt + 1, maxAttempts: maxAttempts)
                }
                
                throw MCPClientError.serverError(code: error.code, message: error.message)
            }
            
            // Decode result
            guard let result = response.result else {
                debugLog("← \(method) id:\(requestId) no result")
                throw MCPClientError.noResult
            }
            
            let resultData = try JSONEncoder().encode(result)
            let decoded = try JSONDecoder().decode(T.self, from: resultData)
            
            logger.debug("Request completed: \(method) (id: \(requestId))")
            debugLog("← \(method) id:\(requestId) ok")
            return decoded
            
        } catch let error as MCPClientError {
            // Already an MCPClientError, check if we should retry
            if attempt < maxAttempts && isRecoverableClientError(error) {
                let delay = exponentialBackoff(attempt: attempt)
                logger.warning("Recoverable client error, retrying after \(delay)s...")
                debugLog("⟳ Retry \(method) after \(delay)s (attempt \(attempt + 1)/\(maxAttempts))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // For transport errors, the SSETransport has already cleared the session
                // We need to reinitialize to get a new session before retrying
                if case .transportError = error {
                    logger.info("Transport error detected, reinitializing...")
                    do {
                        try await reinitialize()
                        logger.info("Reinitialization successful, retrying original request")
                    } catch {
                        logger.error("Reinitialization failed: \(error.localizedDescription)")
                        // Don't throw here - let the retry attempt anyway
                    }
                }
                
                return try await sendRequestWithRetry(method: method, params: params, attempt: attempt + 1, maxAttempts: maxAttempts)
            }
            throw error
        } catch {
            // Network or other error
            if attempt < maxAttempts {
                let delay = exponentialBackoff(attempt: attempt)
                logger.warning("Network error, retrying after \(delay)s: \(error.localizedDescription)")
                debugLog("⟳ Retry \(method) after \(delay)s (attempt \(attempt + 1)/\(maxAttempts))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendRequestWithRetry(method: method, params: params, attempt: attempt + 1, maxAttempts: maxAttempts)
            }
            throw error
        }
    }
    
    /// Check if an error code/message indicates a recoverable error
    private func isRecoverableError(code: Int, message: String) -> Bool {
        let lowerMessage = message.lowercased()
        
        // Session errors (32000 is common for session not found)
        // Also check for "missing mcp-session-id header" which happens after server restart
        if code == -32000 || 
           lowerMessage.contains("session") ||
           lowerMessage.contains("mcp-session-id") {
            return true
        }
        
        // Temporary server errors
        if code >= 500 && code < 600 {
            return true
        }
        
        // Connection errors
        if lowerMessage.contains("connection") || 
           lowerMessage.contains("timeout") ||
           lowerMessage.contains("refused") ||
           lowerMessage.contains("not found") ||
           lowerMessage.contains("404") {
            return true
        }
        
        return false
    }
    
    /// Check if a client error is recoverable
    private func isRecoverableClientError(_ error: MCPClientError) -> Bool {
        switch error {
        case .serverError(let code, let message):
            return isRecoverableError(code: code, message: message)
        case .transportError:
            return true
        case .notInitialized, .clientStopped, .noResult, .decodingError:
            return false
        }
    }
    
    /// Calculate exponential backoff delay
    private func exponentialBackoff(attempt: Int) -> Double {
        // 1s, 2s, 4s, 8s, etc. (capped at 10s)
        return min(pow(2.0, Double(attempt - 1)), 10.0)
    }
    
    /// Reinitialize the connection (for session errors)
    private func reinitialize() async throws {
        logger.info("Reinitializing MCP connection")
        isInitialized = false
        
        // Clear session on SSETransport if applicable
        if let sseTransport = transport as? SSETransport {
            await sseTransport.clearSession()
        }
        
        // Stop and restart the transport to get a fresh connection
        do {
            try await transport.stop()
        } catch {
            // Transport might already be stopped, that's okay
            logger.debug("Transport stop failed (might already be stopped): \(error.localizedDescription)")
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        try await transport.start()
        
        try await initialize()
    }
    
    /// Public method to force a full reconnection (called by AppState when detecting persistent errors)
    public func forceReconnect() async throws {
        logger.warning("Forcing full reconnection")
        isInitialized = false
        
        // Cancel all pending requests
        for continuation in pendingRequests.values {
            continuation.resume(throwing: MCPClientError.clientStopped)
        }
        pendingRequests.removeAll()
        
        // Clear session on SSETransport if applicable
        if let sseTransport = transport as? SSETransport {
            await sseTransport.clearSession()
        }
        
        // Restart transport
        try await transport.stop()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        try await transport.start()
        
        // Reinitialize
        try await initialize()
        logger.info("Reconnection complete")
    }
    
    // MARK: - Response Handling
    
    private func registerPendingRequest(
        id: Int,
        continuation: CheckedContinuation<JSONRPCResponse, Error>
    ) {
        pendingRequests[id] = continuation
    }
    
    private func receiveLoop() async {
        logger.info("Receive loop started")
        while !Task.isCancelled {
            do {
                logger.debug("Receive loop: calling transport.receive()...")
                let data = try await transport.receive()
                logger.info("Receive loop: got \(data.count) bytes")
                
                let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
                logger.debug("Decoded response for request ID: \(response.id)")
                
                if let continuation = pendingRequests.removeValue(forKey: response.id) {
                    logger.debug("Resuming continuation for request \(response.id)")
                    continuation.resume(returning: response)
                } else {
                    logger.warning("Received response for unknown request ID: \(response.id)")
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Error in receive loop: \(error.localizedDescription)")
                }
                // Break loop on error
                break
            }
        }
        logger.info("Receive loop stopped")
    }
    
    // MARK: - Capabilities
    
    /// Get server capabilities
    public func getCapabilities() -> ServerCapabilities? {
        serverCapabilities
    }
    
    /// Check if server supports a capability
    public func hasCapability(_ check: (ServerCapabilities) -> Bool) -> Bool {
        guard let capabilities = serverCapabilities else { return false }
        return check(capabilities)
    }
}

// MARK: - Errors

public enum MCPClientError: Error, LocalizedError {
    case notInitialized
    case clientStopped
    case serverError(code: Int, message: String)
    case noResult
    case transportError(Error)
    case decodingError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "MCP client not initialized"
        case .clientStopped:
            return "MCP client stopped"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .noResult:
            return "No result in response"
        case .transportError(let error):
            return "Transport error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
