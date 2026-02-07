import Foundation
import OSLog

/// Streamable HTTP transport for connecting to a remote MCP server.
///
/// This implements the MCP Streamable HTTP transport (not the old SSE transport).
/// The protocol works like this:
///   1. POST to server URL with JSON-RPC request (no session ID on first request)
///   2. Server responds with JSON-RPC response body + `Mcp-Session-Id` response header
///   3. Client stores session ID and sends it on all subsequent POSTs via `Mcp-Session-Id` header
///   4. Optionally, client opens GET with `Accept: text/event-stream` + session ID for notifications
///
/// This matches how protokoll-vscode connects (see mcpClient.ts).
/// When changing this file, see MCP_SPEC_CHECKLIST.md for spec compliance.
@available(macOS 14.0, *)
public actor SSETransport: MCPTransport {

    // MARK: - Properties

    /// Base server URL (e.g. http://127.0.0.1:3001). We POST to {serverURL}/mcp.
    private let serverURL: URL
    private let logger: Logger
    /// Session ID received from the server's Mcp-Session-Id response header.
    private var sessionId: String?
    private var messageQueue: [Data] = []
    private var receiveWaiters: [CheckedContinuation<Data, Error>] = []
    private var isStopped = false
    private let session: URLSession

    public var isConnected: Bool {
        !isStopped
    }

    // MARK: - Initialization

    public init(
        serverURL: URL,
        logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "http-transport")
    ) {
        // If the user gave us a URL ending in /mcp, strip it so we can append /mcp ourselves.
        // If they gave us just the base (e.g. http://127.0.0.1:3001), use as-is.
        var baseURL = serverURL
        if baseURL.path.hasSuffix("/mcp") {
            baseURL = baseURL.deletingLastPathComponent()
        }
        self.serverURL = baseURL
        self.logger = logger
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)
    }

    public init(
        serverURLString: String,
        logger: Logger = Logger(subsystem: "com.protokoll.mcp", category: "http-transport")
    ) throws {
        guard let url = URL(string: serverURLString) else {
            throw SSETransportError.invalidURL(serverURLString)
        }
        var baseURL = url
        if baseURL.path.hasSuffix("/mcp") {
            baseURL = baseURL.deletingLastPathComponent()
        }
        self.serverURL = baseURL
        self.logger = logger
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)
    }

    /// The endpoint we POST JSON-RPC messages to.
    private var mcpEndpoint: URL {
        serverURL.appendingPathComponent("mcp")
    }

    // MARK: - Lifecycle

    /// Start the transport. For Streamable HTTP, this is a no-op — the session is established
    /// on the first POST (the `initialize` request). No upfront GET is needed.
    public func start() async throws {
        logger.info("Starting Streamable HTTP transport to \(self.serverURL.absoluteString)")
        logger.info("MCP endpoint: \(self.mcpEndpoint.absoluteString)")
        isStopped = false
        sessionId = nil
    }

    public func stop() async throws {
        logger.info("Stopping HTTP transport")
        isStopped = true
        sessionId = nil
        for waiter in receiveWaiters {
            waiter.resume(throwing: SSETransportError.connectionClosed)
        }
        receiveWaiters.removeAll()
        messageQueue.removeAll()
        logger.info("HTTP transport stopped")
    }
    
    /// Clear the session ID to force reinitialization (useful after server restart)
    public func clearSession() {
        logger.info("Clearing session ID")
        sessionId = nil
    }

    // MARK: - Communication

    /// Send a JSON-RPC message to the server via POST.
    /// The response body is queued for `receive()`.
    /// On the first successful response, captures the `Mcp-Session-Id` header.
    public func send(_ message: Data) async throws {
        guard !isStopped else {
            throw SSETransportError.notConnected
        }

        var request = URLRequest(url: mcpEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sid = sessionId {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }
        request.httpBody = message

        if let msgStr = String(data: message, encoding: .utf8) {
            let preview = msgStr.prefix(200)
            logger.info("POST \(self.mcpEndpoint.absoluteString) (session: \(self.sessionId ?? "none")) body: \(preview)")
        }

        let responseData: Data
        let httpResponse: HTTPURLResponse

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw SSETransportError.connectionFailed(error: NSError(domain: "SSETransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
            }
            responseData = data
            httpResponse = http
        } catch let error as SSETransportError {
            throw error
        } catch {
            logger.error("POST failed: \(error.localizedDescription)")
            throw SSETransportError.writeFailed(error: error)
        }

        // Capture session ID from response header (typically on the first `initialize` response)
        if let newSessionId = httpResponse.value(forHTTPHeaderField: "Mcp-Session-Id")
            ?? httpResponse.value(forHTTPHeaderField: "mcp-session-id") {
            if sessionId == nil {
                logger.info("Received session ID from server: \(newSessionId)")
            }
            sessionId = newSessionId
        }

        // Handle 202 Accepted (notifications)
        if httpResponse.statusCode == 202 {
            logger.debug("POST accepted (202), no response body expected")
            return
        }

        // Handle errors
        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyStr = String(data: responseData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errorMessage = bodyStr.isEmpty
                ? "POST \(httpResponse.statusCode)"
                : "POST \(httpResponse.statusCode): \(bodyStr)"
            logger.error("MCP POST failed: \(errorMessage)")
            
            // If we get a 404, 400, or any session-related error, clear the session ID so we can reinitialize
            // This includes "Missing Mcp-Session-Id header" which happens after server restart
            let lowerBody = bodyStr.lowercased()
            if httpResponse.statusCode == 404 || 
               httpResponse.statusCode == 400 ||
               lowerBody.contains("session") ||
               lowerBody.contains("mcp-session-id") {
                logger.warning("Session error detected (status: \(httpResponse.statusCode)), clearing session ID for reinitialization")
                sessionId = nil
            }
            
            throw SSETransportError.writeFailed(error: NSError(domain: "SSETransport", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }

        // Queue the response body for receive()
        if !responseData.isEmpty {
            if let bodyStr = String(data: responseData, encoding: .utf8) {
                let preview = bodyStr.prefix(200)
                logger.debug("Response (\(responseData.count) bytes): \(preview)")
            }
            deliverMessage(responseData)
        }
    }

    /// Receive the next JSON-RPC response. Responses are queued by `send()`.
    public func receive() async throws -> Data {
        if !messageQueue.isEmpty {
            return messageQueue.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation in
            receiveWaiters.append(continuation)
        }
    }

    private func deliverMessage(_ data: Data) {
        if !receiveWaiters.isEmpty {
            receiveWaiters.removeFirst().resume(returning: data)
        } else {
            messageQueue.append(data)
        }
    }
}

// MARK: - Errors

public enum SSETransportError: Error, LocalizedError {
    case invalidURL(String)
    case connectionFailed(error: Error)
    case invalidEndpoint(String)
    case notConnected
    case connectionClosed
    case writeFailed(error: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let s): return "Invalid URL: \(s)"
        case .connectionFailed(let e): return "Connection failed: \(e.localizedDescription)"
        case .invalidEndpoint(let s): return "Invalid endpoint: \(s)"
        case .notConnected: return "Not connected"
        case .connectionClosed: return "Connection closed"
        case .writeFailed(let e): return "Write failed: \(e.localizedDescription)"
        }
    }
}
