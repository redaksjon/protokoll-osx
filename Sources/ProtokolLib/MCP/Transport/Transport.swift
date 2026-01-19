import Foundation

/// Protocol for MCP transport layer
/// Note: Conforming types should be actors for thread safety
public protocol MCPTransport: Sendable {
    /// Start the transport
    @available(macOS 10.15, *)
    func start() async throws
    
    /// Stop the transport
    @available(macOS 10.15, *)
    func stop() async throws
    
    /// Send a message
    @available(macOS 10.15, *)
    func send(_ message: Data) async throws
    
    /// Receive a message
    @available(macOS 10.15, *)
    func receive() async throws -> Data
    
    /// Check if transport is connected
    @available(macOS 10.15, *)
    var isConnected: Bool { get async }
}
