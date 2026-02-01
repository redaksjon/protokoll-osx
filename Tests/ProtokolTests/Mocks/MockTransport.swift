import Foundation
@testable import ProtokolLib

/// Mock transport for testing MCPClient without a real server
@available(macOS 14.0, *)
public actor MockTransport: MCPTransport {
    
    // MARK: - Configuration
    
    /// Error to throw on start
    public var startError: Error?
    
    /// Error to throw on stop
    public var stopError: Error?
    
    /// Error to throw on send
    public var sendError: Error?
    
    /// Error to throw on receive
    public var receiveError: Error?
    
    // MARK: - State
    
    private var _isConnected = false
    private var sentMessages: [Data] = []
    private var responseQueue: [Data] = []
    private var receiveWaiters: [CheckedContinuation<Data, Error>] = []
    
    // Configured responses keyed by method name
    private var configuredResponses: [String: Data] = [:]
    private var configuredErrors: [String: JSONRPCError] = [:]
    private var noResultMethods: Set<String> = []
    
    public var isConnected: Bool {
        _isConnected
    }
    
    /// Get all messages that were sent
    public var allSentMessages: [Data] {
        sentMessages
    }
    
    /// Get the last sent message
    public var lastSentMessage: Data? {
        sentMessages.last
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration Methods
    
    /// Configure the mock to return a specific response for initialize
    public func configureInitializeResponse(
        serverName: String = "MockServer",
        serverVersion: String = "1.0.0"
    ) {
        // Create a proper MCPInitializeResponse JSON string to ensure correct boolean encoding
        let responseJSON = """
        {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {"listChanged": true}},
            "serverInfo": {"name": "\(serverName)", "version": "\(serverVersion)"}
        }
        """
        
        if let data = responseJSON.data(using: .utf8) {
            configuredResponses["initialize"] = data
        }
    }
    
    /// Configure a generic JSON-RPC success response with JSON string
    public func configureSuccessResponse(for method: String, result: [String: Any]) {
        // Convert result to JSON string, handling booleans explicitly
        var jsonParts: [String] = []
        for (key, value) in result {
            let jsonValue: String
            if let boolValue = value as? Bool {
                jsonValue = boolValue ? "true" : "false"
            } else if let intValue = value as? Int {
                jsonValue = "\(intValue)"
            } else if let doubleValue = value as? Double {
                jsonValue = "\(doubleValue)"
            } else if let stringValue = value as? String {
                jsonValue = "\"\(stringValue)\""
            } else {
                // For other types, use JSONSerialization
                if let data = try? JSONSerialization.data(withJSONObject: value),
                   let str = String(data: data, encoding: .utf8) {
                    jsonValue = str
                } else {
                    jsonValue = "null"
                }
            }
            jsonParts.append("\"\(key)\":\(jsonValue)")
        }
        let resultJSON = "{\(jsonParts.joined(separator: ","))}"
        configuredResponses[method] = resultJSON.data(using: .utf8)
    }
    
    /// Configure a JSON-RPC error response
    public func configureErrorResponse(for method: String, code: Int, message: String) {
        configuredErrors[method] = JSONRPCError(code: code, message: message)
    }
    
    /// Configure a response with no result
    public func configureNoResultResponse(for method: String) {
        noResultMethods.insert(method)
    }
    
    /// Queue a response to be returned on next receive
    public func queueResponse(_ data: Data) {
        if !receiveWaiters.isEmpty {
            let waiter = receiveWaiters.removeFirst()
            waiter.resume(returning: data)
        } else {
            responseQueue.append(data)
        }
    }
    
    /// Set start error
    public func setStartError(_ error: Error?) {
        startError = error
    }
    
    /// Set stop error
    public func setStopError(_ error: Error?) {
        stopError = error
    }
    
    /// Set receive error
    public func setReceiveError(_ error: Error?) {
        receiveError = error
    }
    
    /// Set a raw JSON response for a method
    public func setRawResponse(for method: String, json: String) {
        configuredResponses[method] = json.data(using: .utf8)
    }
    
    // MARK: - MCPTransport Protocol
    
    public func start() async throws {
        if let error = startError {
            throw error
        }
        _isConnected = true
    }
    
    public func stop() async throws {
        if let error = stopError {
            throw error
        }
        _isConnected = false
        
        // Cancel any pending receives
        for waiter in receiveWaiters {
            waiter.resume(throwing: MockTransportError.connectionClosed)
        }
        receiveWaiters.removeAll()
    }
    
    public func send(_ message: Data) async throws {
        if let error = sendError {
            throw error
        }
        
        guard _isConnected else {
            throw MockTransportError.notConnected
        }
        
        sentMessages.append(message)
        
        // Try to generate a response based on the request
        if let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: message) {
            let method = request.method
            
            // Check for configured error
            if let errorResponse = configuredErrors[method] {
                // Build response JSON manually to preserve types
                let responseJSON = """
                {"jsonrpc":"2.0","id":\(request.id),"error":{"code":\(errorResponse.code),"message":"\(errorResponse.message)"}}
                """
                if let responseData = responseJSON.data(using: .utf8) {
                    queueResponse(responseData)
                }
                return
            }
            
            // Check for no-result response
            if noResultMethods.contains(method) {
                let responseJSON = """
                {"jsonrpc":"2.0","id":\(request.id)}
                """
                if let responseData = responseJSON.data(using: .utf8) {
                    queueResponse(responseData)
                }
                return
            }
            
            // Check for configured success response
            if let resultData = configuredResponses[method] {
                // Build response with result JSON directly embedded
                if let resultString = String(data: resultData, encoding: .utf8) {
                    let responseJSON = """
                    {"jsonrpc":"2.0","id":\(request.id),"result":\(resultString)}
                    """
                    if let responseData = responseJSON.data(using: .utf8) {
                        queueResponse(responseData)
                    }
                }
            }
        }
    }
    
    public func receive() async throws -> Data {
        if let error = receiveError {
            throw error
        }
        
        // If we have queued responses, return the first one
        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }
        
        // Otherwise, wait for a response
        return try await withCheckedThrowingContinuation { continuation in
            receiveWaiters.append(continuation)
        }
    }
    
    // MARK: - Test Helpers
    
    /// Reset the mock state
    public func reset() {
        _isConnected = false
        sentMessages.removeAll()
        responseQueue.removeAll()
        configuredResponses.removeAll()
        configuredErrors.removeAll()
        noResultMethods.removeAll()
        startError = nil
        stopError = nil
        sendError = nil
        receiveError = nil
        
        // Cancel waiters
        for waiter in receiveWaiters {
            waiter.resume(throwing: MockTransportError.reset)
        }
        receiveWaiters.removeAll()
    }
    
    /// Get the number of messages sent
    public var sentMessageCount: Int {
        sentMessages.count
    }
    
    /// Check if a specific method was called
    public func wasMethodCalled(_ method: String) -> Bool {
        sentMessages.contains { data in
            if let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) {
                return request.method == method
            }
            return false
        }
    }
}

// MARK: - Errors

public enum MockTransportError: Error, LocalizedError {
    case notConnected
    case connectionClosed
    case reset
    case configuredError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Mock transport not connected"
        case .connectionClosed:
            return "Mock transport connection closed"
        case .reset:
            return "Mock transport was reset"
        case .configuredError(let message):
            return message
        }
    }
}
