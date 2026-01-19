import Foundation

// MARK: - JSON-RPC 2.0 Types

/// JSON-RPC 2.0 Request
public struct JSONRPCRequest: Codable, Equatable {
    public let jsonrpc: String
    public let id: Int
    public let method: String
    public let params: AnyCodable?
    
    public init(id: Int, method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
    
    public static func == (lhs: JSONRPCRequest, rhs: JSONRPCRequest) -> Bool {
        lhs.jsonrpc == rhs.jsonrpc && lhs.id == rhs.id && lhs.method == rhs.method
    }
}

/// JSON-RPC 2.0 Response
public struct JSONRPCResponse: Codable {
    public let jsonrpc: String
    public let id: Int
    public let result: AnyCodable?
    public let error: JSONRPCError?
    
    public var isError: Bool {
        error != nil
    }
    
    public init(jsonrpc: String = "2.0", id: Int, result: AnyCodable? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }
}

/// JSON-RPC 2.0 Error
public struct JSONRPCError: Codable, Error, Equatable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?
    
    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
    
    public static func == (lhs: JSONRPCError, rhs: JSONRPCError) -> Bool {
        lhs.code == rhs.code && lhs.message == rhs.message
    }
}

/// JSON-RPC 2.0 Notification (no id, no response expected)
public struct JSONRPCNotification: Codable, Equatable {
    public let jsonrpc: String
    public let method: String
    public let params: AnyCodable?
    
    public init(method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
    
    public static func == (lhs: JSONRPCNotification, rhs: JSONRPCNotification) -> Bool {
        lhs.jsonrpc == rhs.jsonrpc && lhs.method == rhs.method
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable value for dynamic JSON
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }
}
