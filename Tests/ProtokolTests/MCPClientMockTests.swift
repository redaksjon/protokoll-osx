import XCTest
@testable import ProtokolLib

/// Tests for MCPClient using MockTransport
/// These tests cover code paths that require a "working" transport
@available(macOS 14.0, *)
final class MCPClientMockTests: XCTestCase {
    
    // MARK: - Start/Initialize Tests
    
    func testStartSuccessfullyInitializes() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let client = MCPClient(transport: transport)
        
        try await client.start()
        
        let isReady = await client.isReady
        XCTAssertTrue(isReady, "Client should be ready after successful start")
        
        // Verify initialize was called
        let wasCalled = await transport.wasMethodCalled("initialize")
        XCTAssertTrue(wasCalled, "initialize method should have been called")
        
        try await client.stop()
    }
    
    func testStartSetsCapabilities() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse(serverName: "TestServer", serverVersion: "2.0.0")
        
        let client = MCPClient(transport: transport)
        
        try await client.start()
        
        let capabilities = await client.getCapabilities()
        XCTAssertNotNil(capabilities, "Should have capabilities after initialize")
        
        try await client.stop()
    }
    
    func testStartFailsWhenTransportFails() async throws {
        let transport = MockTransport()
        await transport.setStartError(MockTransportError.configuredError("Start failed"))
        
        let client = MCPClient(transport: transport)
        
        do {
            try await client.start()
            XCTFail("Expected start to fail")
        } catch {
            // Expected
        }
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady, "Client should not be ready after failed start")
    }
    
    // MARK: - Stop Tests
    
    func testStopCancelsReceiveLoop() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let client = MCPClient(transport: transport)
        
        try await client.start()
        try await client.stop()
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady, "Client should not be ready after stop")
    }
    
    // MARK: - SendRequest Tests
    
    func testSendRequestWithoutParams() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        await transport.configureSuccessResponse(for: "test/simple", result: ["status": "ok"])
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct SimpleResponse: Codable {
            let status: String
        }
        
        let response: SimpleResponse = try await client.sendRequest(method: "test/simple")
        XCTAssertEqual(response.status, "ok")
        
        try await client.stop()
    }
    
    func testSendRequestWithParams() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        await transport.configureSuccessResponse(for: "test/echo", result: ["echoed": true])
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct EchoParams: Codable {
            let message: String
        }
        struct EchoResponse: Codable {
            let echoed: Bool
        }
        
        let response: EchoResponse = try await client.sendRequest(
            method: "test/echo",
            params: EchoParams(message: "hello")
        )
        XCTAssertTrue(response.echoed)
        
        try await client.stop()
    }
    
    func testSendRequestHandlesServerError() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        await transport.configureErrorResponse(for: "test/error", code: -32600, message: "Invalid Request")
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct TestResponse: Codable { let data: String }
        
        do {
            let _: TestResponse = try await client.sendRequest(method: "test/error")
            XCTFail("Expected server error")
        } catch let error as MCPClientError {
            if case .serverError(let code, let message) = error {
                XCTAssertEqual(code, -32600)
                XCTAssertEqual(message, "Invalid Request")
            } else {
                XCTFail("Expected serverError, got: \(error)")
            }
        }
        
        try await client.stop()
    }
    
    func testSendRequestHandlesNoResult() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        await transport.configureNoResultResponse(for: "test/empty")
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct TestResponse: Codable { let data: String }
        
        do {
            let _: TestResponse = try await client.sendRequest(method: "test/empty")
            XCTFail("Expected noResult error")
        } catch let error as MCPClientError {
            if case .noResult = error {
                // Expected
            } else {
                XCTFail("Expected noResult, got: \(error)")
            }
        }
        
        try await client.stop()
    }
    
    func testSendMultipleRequests() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        await transport.configureSuccessResponse(for: "test/1", result: ["id": 1])
        await transport.configureSuccessResponse(for: "test/2", result: ["id": 2])
        await transport.configureSuccessResponse(for: "test/3", result: ["id": 3])
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct IdResponse: Codable {
            let id: Int
        }
        
        let r1: IdResponse = try await client.sendRequest(method: "test/1")
        let r2: IdResponse = try await client.sendRequest(method: "test/2")
        let r3: IdResponse = try await client.sendRequest(method: "test/3")
        
        XCTAssertEqual(r1.id, 1)
        XCTAssertEqual(r2.id, 2)
        XCTAssertEqual(r3.id, 3)
        
        try await client.stop()
    }
    
    // MARK: - Capabilities Tests
    
    func testHasCapabilityWithTools() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let hasTools = await client.hasCapability { $0.tools != nil }
        XCTAssertTrue(hasTools, "Should have tools capability")
        
        try await client.stop()
    }
    
    // MARK: - IsReady Tests
    
    func testIsReadyRequiresBothInitializedAndConnected() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let client = MCPClient(transport: transport)
        
        // Before start - not ready
        var isReady = await client.isReady
        XCTAssertFalse(isReady)
        
        // After start - ready
        try await client.start()
        isReady = await client.isReady
        XCTAssertTrue(isReady)
        
        // After stop - not ready
        try await client.stop()
        isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
}

// MARK: - MCPClient+Tools Mock Tests

@available(macOS 14.0, *)
final class MCPClientToolsMockTests: XCTestCase {
    
    // MARK: - listTools Tests
    
    func testListTools() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Configure tools/list response
        let toolsResponse = """
        {"tools":[{"name":"test_tool","description":"A test tool","inputSchema":{"type":"object"}}]}
        """
        await transport.setRawResponse(for: "tools/list", json: toolsResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let tools = try await client.listTools()
        
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.name, "test_tool")
        
        try await client.stop()
    }
    
    func testListToolsEmpty() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let toolsResponse = """
        {"tools":[]}
        """
        await transport.setRawResponse(for: "tools/list", json: toolsResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let tools = try await client.listTools()
        XCTAssertTrue(tools.isEmpty)
        
        try await client.stop()
    }
    
    // MARK: - callTool Tests
    
    func testCallTool() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let callResponse = """
        {"content":[{"type":"text","text":"Hello, World!"}],"isError":false}
        """
        await transport.setRawResponse(for: "tools/call", json: callResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let response = try await client.callTool(name: "greeting", arguments: [:])
        
        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.content.first?.type, "text")
        XCTAssertEqual(response.content.first?.text, "Hello, World!")
        XCTAssertEqual(response.isError, false)
        
        try await client.stop()
    }
    
    func testCallToolWithArguments() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let callResponse = """
        {"content":[{"type":"text","text":"result"}],"isError":false}
        """
        await transport.setRawResponse(for: "tools/call", json: callResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let response = try await client.callTool(
            name: "compute",
            arguments: ["input": 42, "flag": true]
        )
        
        XCTAssertEqual(response.content.first?.text, "result")
        
        try await client.stop()
    }
    
    func testCallToolWithError() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let callResponse = """
        {"content":[{"type":"text","text":"Error occurred"}],"isError":true}
        """
        await transport.setRawResponse(for: "tools/call", json: callResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let response = try await client.callTool(name: "failing_tool")
        
        XCTAssertEqual(response.isError, true)
        
        try await client.stop()
    }
    
    // MARK: - callToolWithTextResult Tests
    
    func testCallToolWithTextResult() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Response with text content containing JSON
        let callResponse = """
        {"content":[{"type":"text","text":"{\\"value\\":42,\\"name\\":\\"test\\"}"}],"isError":false}
        """
        await transport.setRawResponse(for: "tools/call", json: callResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct TestResult: Decodable {
            let value: Int
            let name: String
        }
        
        let result: TestResult = try await client.callToolWithTextResult(name: "json_tool")
        
        XCTAssertEqual(result.value, 42)
        XCTAssertEqual(result.name, "test")
        
        try await client.stop()
    }
    
    func testCallToolWithTextResultNoTextContent() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Response with no text content
        let callResponse = """
        {"content":[{"type":"image","data":"base64data"}],"isError":false}
        """
        await transport.setRawResponse(for: "tools/call", json: callResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        struct TestResult: Decodable {
            let value: Int
        }
        
        do {
            let _: TestResult = try await client.callToolWithTextResult(name: "image_tool")
            XCTFail("Expected noResult error")
        } catch let error as MCPClientError {
            if case .noResult = error {
                // Expected
            } else {
                XCTFail("Expected noResult, got: \(error)")
            }
        }
        
        try await client.stop()
    }
}

// MARK: - MCPClient+Resources Mock Tests

@available(macOS 14.0, *)
final class MCPClientResourcesMockTests: XCTestCase {
    
    // MARK: - listResources Tests
    
    func testListResources() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let resourcesResponse = """
        {"resources":[{"uri":"protokoll://config","name":"Config","description":"Configuration"}]}
        """
        await transport.setRawResponse(for: "resources/list", json: resourcesResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let response = try await client.listResources()
        
        XCTAssertEqual(response.resources.count, 1)
        XCTAssertEqual(response.resources.first?.uri, "protokoll://config")
        
        try await client.stop()
    }
    
    // MARK: - readResource Tests
    
    func testReadResource() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let readResponse = """
        {"contents":[{"uri":"protokoll://config","mimeType":"application/json","text":"{\\"hasContext\\":true}"}]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let content = try await client.readResource(uri: "protokoll://config")
        
        XCTAssertEqual(content.uri, "protokoll://config")
        XCTAssertNotNil(content.text)
        
        try await client.stop()
    }
    
    func testReadResourceNoContent() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Response with empty contents array
        let readResponse = """
        {"contents":[]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        do {
            _ = try await client.readResource(uri: "protokoll://missing")
            XCTFail("Expected noResult error")
        } catch let error as MCPClientError {
            if case .noResult = error {
                // Expected
            } else {
                XCTFail("Expected noResult, got: \(error)")
            }
        }
        
        try await client.stop()
    }
    
    // MARK: - Convenience Method Tests
    
    func testListTranscriptsResource() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Configure response for resources/read with transcript list JSON
        let transcriptListJSON = """
        {"directory":"/output","transcripts":[{"path":"/output/test.md","filename":"test.md","date":"2024-01-15","title":"Test"}],"pagination":{"total":1,"limit":50,"offset":0,"hasMore":false}}
        """
        let readResponse = """
        {"contents":[{"uri":"protokoll://transcripts","mimeType":"application/json","text":"\(transcriptListJSON.replacingOccurrences(of: "\"", with: "\\\""))"}]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let result = try await client.listTranscriptsResource(directory: "/output")
        
        XCTAssertEqual(result.directory, "/output")
        XCTAssertEqual(result.transcripts.count, 1)
        XCTAssertEqual(result.total, 1)
        
        try await client.stop()
    }
    
    func testReadTranscriptResource() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let readResponse = """
        {"contents":[{"uri":"protokoll://transcript/test.md","mimeType":"text/markdown","text":"# Test Transcript\\n\\nContent here."}]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let markdown = try await client.readTranscriptResource(path: "test.md")
        
        XCTAssertTrue(markdown.contains("Test Transcript"))
        
        try await client.stop()
    }
    
    func testReadTranscriptResourceNoText() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        // Response with no text field
        let readResponse = """
        {"contents":[{"uri":"protokoll://transcript/test.md","mimeType":"text/markdown"}]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        do {
            _ = try await client.readTranscriptResource(path: "test.md")
            XCTFail("Expected noResult error")
        } catch let error as MCPClientError {
            if case .noResult = error { /* Expected */ }
        }
        
        try await client.stop()
    }
    
    func testListEntitiesResource() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let entitiesJSON = """
        {"type":"person","entities":[{"id":"1","name":"John Doe","uri":"protokoll://entity/person/1"}]}
        """
        let readResponse = """
        {"contents":[{"uri":"protokoll://entities/person","mimeType":"application/json","text":"\(entitiesJSON.replacingOccurrences(of: "\"", with: "\\\""))"}]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let result = try await client.listEntitiesResource(type: "person")
        
        XCTAssertEqual(result.type, "person")
        XCTAssertEqual(result.entities.count, 1)
        XCTAssertEqual(result.entities.first?.name, "John Doe")
        
        try await client.stop()
    }
    
    func testGetConfigResource() async throws {
        let transport = MockTransport()
        await transport.configureInitializeResponse()
        
        let configJSON = """
        {"hasContext":true,"contextPath":"/path","entityCounts":{"projects":5,"people":10,"terms":3,"companies":2},"resources":["protokoll://config"]}
        """
        let readResponse = """
        {"contents":[{"uri":"protokoll://config","mimeType":"application/json","text":"\(configJSON.replacingOccurrences(of: "\"", with: "\\\""))"}]}
        """
        await transport.setRawResponse(for: "resources/read", json: readResponse)
        
        let client = MCPClient(transport: transport)
        try await client.start()
        
        let config = try await client.getConfigResource()
        
        XCTAssertTrue(config.hasContext)
        XCTAssertEqual(config.contextPath, "/path")
        XCTAssertEqual(config.entityCounts.projects, 5)
        XCTAssertEqual(config.entityCounts.people, 10)
        
        try await client.stop()
    }
    
    // MARK: - Additional Edge Cases
    
    func testNotInitializedErrorDescription() async throws {
        // Test the error description for not initialized
        let error = MCPClientError.notInitialized
        XCTAssertEqual(error.errorDescription, "MCP client not initialized")
    }
    
    func testClientStoppedErrorDescription() async throws {
        // Just test the error description without complex async scenarios
        let error = MCPClientError.clientStopped
        XCTAssertEqual(error.errorDescription, "MCP client stopped")
    }
    
    func testTransportErrorErrorDescription() async throws {
        let underlyingError = StdioTransportError.connectionClosed
        let error = MCPClientError.transportError(underlyingError)
        
        XCTAssertTrue(error.errorDescription?.contains("Transport error") == true)
    }
    
    func testDecodingErrorErrorDescription() async throws {
        struct TestDecodingError: Error, LocalizedError {
            var errorDescription: String? { "Test decoding error" }
        }
        
        let error = MCPClientError.decodingError(TestDecodingError())
        
        XCTAssertTrue(error.errorDescription?.contains("Decoding error") == true)
    }
}
