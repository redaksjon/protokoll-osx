import Foundation

// MARK: - Resource Types

/// Resource Definition
public struct Resource: Codable, Identifiable, Equatable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    
    public var id: String { uri }
    
    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

/// List Resources Response
public struct ListResourcesResponse: Codable {
    public let resources: [Resource]
    public let resourceTemplates: [ResourceTemplate]?
}

/// Resource Template
public struct ResourceTemplate: Codable, Equatable {
    public let uriTemplate: String
    public let name: String
    public let description: String?
    public let mimeType: String?
}

/// Read Resource Request Parameters
public struct ReadResourceParams: Codable {
    public let uri: String
    
    public init(uri: String) {
        self.uri = uri
    }
}

/// Read Resource Response
public struct ReadResourceResponse: Codable {
    public let contents: [ResourceContent]
}

/// Resource Content
public struct ResourceContent: Codable {
    public let uri: String
    public let mimeType: String?
    public let text: String?
    public let blob: String? // Base64-encoded binary data
}

// MARK: - Resource URIs

/// Helper for constructing Protokoll resource URIs
public enum ProtokolResourceURI {
    case transcript(path: String)
    case entity(type: String, id: String)
    case transcripts(directory: String? = nil, limit: Int? = nil, offset: Int? = nil)
    case entities(type: String)
    case config
    
    public var uri: String {
        switch self {
        case .transcript(let path):
            return "protokoll://transcript/\(path)"
        case .entity(let type, let id):
            return "protokoll://entity/\(type)/\(id)"
        case .transcripts(let directory, let limit, let offset):
            var params: [String] = []
            // Only include directory if provided (server uses its configured output directory as fallback)
            if let directory = directory, !directory.isEmpty {
                params.append("directory=\(directory.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? directory)")
            }
            if let limit = limit {
                params.append("limit=\(limit)")
            }
            if let offset = offset {
                params.append("offset=\(offset)")
            }
            let query = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
            return "protokoll://transcripts\(query)"
        case .entities(let type):
            return "protokoll://entities/\(type)"
        case .config:
            return "protokoll://config"
        }
    }
}

// MARK: - Parsed Resource Data

/// Transcripts list from resource
public struct TranscriptsListResource: Codable {
    public let directory: String
    public let transcripts: [TranscriptMetadata]
    public let pagination: Pagination
    public let filters: Filters?
    
    public struct TranscriptMetadata: Codable {
        public let uri: String?
        public let path: String
        public let filename: String
        public let date: String
        public let time: String?
        public let title: String
        public let status: String?
        public let openTasksCount: Int?
        public let contentSize: Int?
        public let entities: TranscriptEntities?
        
        public struct TranscriptEntities: Codable {
            public let people: [EntityRef]?
            public let projects: [EntityRef]?
            public let terms: [EntityRef]?
            public let companies: [EntityRef]?
        }
        
        public struct EntityRef: Codable {
            public let id: String
            public let name: String
        }
    }
    
    public struct Pagination: Codable {
        public let total: Int
        public let limit: Int
        public let offset: Int
        public let hasMore: Bool
    }
    
    public struct Filters: Codable {
        public let startDate: String?
        public let endDate: String?
    }
    
    // Convenience accessors
    public var total: Int { pagination.total }
    public var hasMore: Bool { pagination.hasMore }
}

/// Entities list from resource
public struct EntitiesListResource: Codable {
    public let type: String
    public let entities: [EntityRef]
    
    public struct EntityRef: Codable {
        public let id: String
        public let name: String
        public let uri: String
    }
}

/// Config from resource
public struct ConfigResource: Codable {
    public let hasContext: Bool
    public let contextPath: String
    public let entityCounts: EntityCounts
    public let resources: [String]
    
    public struct EntityCounts: Codable {
        public let projects: Int
        public let people: Int
        public let terms: Int
        public let companies: Int
    }
}

// MARK: - Transcript Content Response

/// Structured transcript content returned by MCP server
/// The server returns all metadata pre-parsed - clients should NOT parse this
public struct TranscriptContentResource: Codable {
    public let uri: String
    public let path: String
    public let title: String
    public let metadata: TranscriptContentMetadata
    public let content: String
    
    public struct TranscriptContentMetadata: Codable {
        public let date: String?
        public let time: String?
        public let project: String?
        public let projectId: String?
        public let status: String?
        public let tags: [String]?
        public let duration: Double?
        public let entities: TranscriptEntities?
        public let tasks: [TranscriptTask]?
        public let history: [StatusTransition]?
        public let routing: RoutingInfo?
        
        public struct TranscriptEntities: Codable {
            public let people: [EntityRef]?
            public let projects: [EntityRef]?
            public let terms: [EntityRef]?
            public let companies: [EntityRef]?
            
            public struct EntityRef: Codable {
                public let id: String
                public let name: String
            }
        }
        
        public struct TranscriptTask: Codable, Identifiable {
            public let id: String
            public let description: String
            public let status: String
            public let created: String
            public let changed: String?
            public let completed: String?
        }
        
        public struct StatusTransition: Codable {
            public let from: String
            public let to: String
            public let at: String
        }
        
        public struct RoutingInfo: Codable {
            public let destination: String?
            public let confidence: String?
        }
    }
}
