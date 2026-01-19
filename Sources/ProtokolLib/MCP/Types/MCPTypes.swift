import Foundation

// MARK: - MCP Protocol Types

/// MCP Initialize Request
public struct MCPInitializeRequest: Codable {
    public let protocolVersion: String
    public let capabilities: ClientCapabilities
    public let clientInfo: ClientInfo
    
    public init(protocolVersion: String, capabilities: ClientCapabilities, clientInfo: ClientInfo) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
    }
}

/// MCP Initialize Response
public struct MCPInitializeResponse: Codable {
    public let protocolVersion: String
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo
}

/// Client Capabilities
public struct ClientCapabilities: Codable {
    public let roots: RootsCapability?
    public let sampling: SamplingCapability?
    
    public struct RootsCapability: Codable {
        public let listChanged: Bool?
        
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }
    
    public struct SamplingCapability: Codable {
        public init() {}
    }
    
    public init(roots: RootsCapability? = nil, sampling: SamplingCapability? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
}

/// Server Capabilities
public struct ServerCapabilities: Codable {
    public let tools: ToolsCapability?
    public let resources: ResourcesCapability?
    public let prompts: PromptsCapability?
    
    public struct ToolsCapability: Codable {
        public let listChanged: Bool?
    }
    
    public struct ResourcesCapability: Codable {
        public let subscribe: Bool?
        public let listChanged: Bool?
    }
    
    public struct PromptsCapability: Codable {
        public let listChanged: Bool?
    }
}

/// Client Info
public struct ClientInfo: Codable, Equatable {
    public let name: String
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Server Info
public struct ServerInfo: Codable, Equatable {
    public let name: String
    public let version: String
}

// MARK: - MCP Error Codes

public enum MCPErrorCode: Int {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
    
    // MCP-specific errors
    case serverNotInitialized = -32002
    case unknownError = -32001
}
