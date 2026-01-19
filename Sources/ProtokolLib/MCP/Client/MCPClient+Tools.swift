import Foundation

// MARK: - Tool Methods

public extension MCPClient {
    
    /// List available tools
    func listTools() async throws -> [Tool] {
        let response: ListToolsResponse = try await sendRequest(method: "tools/list")
        return response.tools
    }
    
    /// Call a tool
    func callTool(
        name: String,
        arguments: [String: Any] = [:]
    ) async throws -> CallToolResponse {
        let params = CallToolParams(
            name: name,
            arguments: arguments.mapValues { AnyCodable($0) }
        )
        
        return try await sendRequest(method: "tools/call", params: params)
    }
    
    /// Call a tool and decode the text result
    func callToolWithTextResult<T: Decodable>(
        name: String,
        arguments: [String: Any] = [:]
    ) async throws -> T {
        let response = try await callTool(name: name, arguments: arguments)
        
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw MCPClientError.noResult
        }
        
        let data = text.data(using: .utf8)!
        return try JSONDecoder().decode(T.self, from: data)
    }
}
