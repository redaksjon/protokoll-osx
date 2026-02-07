import Foundation

// MARK: - Resource Methods

public extension MCPClient {
    
    /// List available resources
    func listResources() async throws -> ListResourcesResponse {
        return try await sendRequest(method: "resources/list")
    }
    
    /// Read a resource by URI
    func readResource(uri: String) async throws -> ResourceContent {
        let params = ReadResourceParams(uri: uri)
        let response: ReadResourceResponse = try await sendRequest(
            method: "resources/read",
            params: params
        )
        
        guard let content = response.contents.first else {
            throw MCPClientError.noResult
        }
        
        return content
    }
    
    // MARK: - Convenience Methods
    
    /// List transcripts via resource (preferred over tool)
    /// Pass nil or empty directory to let the server use its own configured output directory
    func listTranscriptsResource(
        directory: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> TranscriptsListResource {
        let uri = ProtokolResourceURI.transcripts(
            directory: directory,
            limit: limit,
            offset: offset
        ).uri
        
        let content = try await readResource(uri: uri)
        
        guard let text = content.text,
              let data = text.data(using: .utf8) else {
            throw MCPClientError.noResult
        }
        
        return try JSONDecoder().decode(TranscriptsListResource.self, from: data)
    }
    
    /// Read a transcript via resource
    func readTranscriptResource(path: String) async throws -> String {
        let uri = ProtokolResourceURI.transcript(path: path).uri
        let content = try await readResource(uri: uri)
        
        guard let text = content.text else {
            throw MCPClientError.noResult
        }
        
        return text // Markdown content
    }
    
    /// List entities via resource
    func listEntitiesResource(type: String) async throws -> EntitiesListResource {
        let uri = ProtokolResourceURI.entities(type: type).uri
        let content = try await readResource(uri: uri)
        
        guard let text = content.text,
              let data = text.data(using: .utf8) else {
            throw MCPClientError.noResult
        }
        
        return try JSONDecoder().decode(EntitiesListResource.self, from: data)
    }
    
    /// Get config via resource
    func getConfigResource() async throws -> ConfigResource {
        let uri = ProtokolResourceURI.config.uri
        let content = try await readResource(uri: uri)
        
        guard let text = content.text,
              let data = text.data(using: .utf8) else {
            throw MCPClientError.noResult
        }
        
        return try JSONDecoder().decode(ConfigResource.self, from: data)
    }
}
