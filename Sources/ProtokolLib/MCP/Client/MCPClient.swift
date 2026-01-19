import Foundation
import OSLog

/// Main MCP client for communicating with protokoll-mcp server
@available(macOS 14.0, *)
public actor MCPClient {
    
    // MARK: - Properties
    
    private let transport: StdioTransport
    private let logger: Logger
    private var nextRequestId: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]
    private var isInitialized = false
    private var serverCapabilities: ServerCapabilities?
    private var receiveTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init(transport: StdioTransport, logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "client")) {
        self.transport = transport
        self.logger = logger
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
        
        let response: MCPInitializeResponse = try await sendRequest(
            method: "initialize",
            params: initRequest
        )
        
        serverCapabilities = response.capabilities
        isInitialized = true
        
        logger.info("MCP initialized with server: \(response.serverInfo.name) v\(response.serverInfo.version)")
    }
    
    // MARK: - Request/Response
    
    /// Send a request and wait for response
    public func sendRequest<T: Decodable>(
        method: String,
        params: (any Encodable)? = nil
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
        
        logger.info("Sending request: \(method) (id: \(requestId))")
        
        // Encode and send request
        let requestData = try JSONEncoder().encode(request)
        logger.debug("Request data: \(requestData.count) bytes")
        try await transport.send(requestData)
        logger.debug("Request sent, waiting for response...")
        
        // Wait for response
        let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONRPCResponse, Error>) in
            Task {
                self.registerPendingRequest(id: requestId, continuation: continuation)
                logger.debug("Registered pending request \(requestId)")
            }
        }
        
        logger.debug("Response received for request \(requestId)")
        
        // Handle error response
        if let error = response.error {
            logger.error("Request failed: \(error.message)")
            throw MCPClientError.serverError(code: error.code, message: error.message)
        }
        
        // Decode result
        guard let result = response.result else {
            throw MCPClientError.noResult
        }
        
        let resultData = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(T.self, from: resultData)
        
        logger.debug("Request completed: \(method) (id: \(requestId))")
        return decoded
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
