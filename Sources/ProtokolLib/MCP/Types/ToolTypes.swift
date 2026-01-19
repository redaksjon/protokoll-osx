import Foundation

// MARK: - Tool Types

/// Tool Definition
public struct Tool: Codable, Identifiable, Equatable {
    public let name: String
    public let description: String?
    public let inputSchema: ToolInputSchema
    
    public var id: String { name }
    
    public init(name: String, description: String? = nil, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
    
    public static func == (lhs: Tool, rhs: Tool) -> Bool {
        lhs.name == rhs.name && lhs.description == rhs.description
    }
}

/// Tool Input Schema
public struct ToolInputSchema: Codable, Equatable {
    public let type: String
    public let properties: [String: PropertySchema]?
    public let required: [String]?
    
    public init(type: String = "object", properties: [String: PropertySchema]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
    
    public static func == (lhs: ToolInputSchema, rhs: ToolInputSchema) -> Bool {
        lhs.type == rhs.type && lhs.required == rhs.required
    }
}

/// Property Schema
public struct PropertySchema: Codable, Equatable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let items: ItemsSchema?
    public let `default`: AnyCodable?
    
    public init(type: String, description: String? = nil, `enum`: [String]? = nil, items: ItemsSchema? = nil, `default`: AnyCodable? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self.items = items
        self.default = `default`
    }
    
    public static func == (lhs: PropertySchema, rhs: PropertySchema) -> Bool {
        lhs.type == rhs.type && lhs.description == rhs.description && lhs.enum == rhs.enum
    }
}

/// Items Schema (for arrays)
public struct ItemsSchema: Codable, Equatable {
    public let type: String
    
    public init(type: String) {
        self.type = type
    }
}

/// List Tools Response
public struct ListToolsResponse: Codable {
    public let tools: [Tool]
}

/// Call Tool Request Parameters
public struct CallToolParams: Codable {
    public let name: String
    public let arguments: [String: AnyCodable]?
    
    public init(name: String, arguments: [String: AnyCodable]? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// Call Tool Response
public struct CallToolResponse: Codable {
    public let content: [ContentItem]
    public let isError: Bool?
}

/// Content Item
public struct ContentItem: Codable, Equatable {
    public let type: String
    public let text: String?
    public let data: String? // For binary data
    public let mimeType: String?
    
    public init(type: String, text: String? = nil, data: String? = nil, mimeType: String? = nil) {
        self.type = type
        self.text = text
        self.data = data
        self.mimeType = mimeType
    }
}
