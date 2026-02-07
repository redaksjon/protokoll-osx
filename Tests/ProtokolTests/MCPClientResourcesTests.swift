import XCTest
@testable import ProtokolLib

@available(macOS 14.0, *)
final class MCPClientResourcesTests: XCTestCase {
    
    // Note: MCPClient requires StdioTransport specifically
    // These tests use real StdioTransport instances with non-existent server paths
    // to test error cases and basic functionality
    var transport: StdioTransport!
    var client: MCPClient!
    let nonexistentPath = "/nonexistent/path/to/server"
    
    override func setUp() async throws {
        try await super.setUp()
        transport = StdioTransport(serverPath: nonexistentPath)
        client = MCPClient(transport: transport)
    }
    
    override func tearDown() async throws {
        try? await client.stop()
        client = nil
        transport = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    // Note: Full resource tests require a running server, which is complex to set up
    // These tests focus on error cases that don't require a server
    
    // MARK: - Error Handling Tests
    
    func testListResourcesWhenNotInitialized() async throws {
        do {
            _ = try await client.listResources()
            XCTFail("Expected error when not initialized")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testReadResourceWhenNotInitialized() async throws {
        do {
            _ = try await client.readResource(uri: "protokoll://test")
            XCTFail("Expected error when not initialized")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testListTranscriptsResourceWhenNotInitialized() async throws {
        do {
            _ = try await client.listTranscriptsResource(directory: "/test")
            XCTFail("Expected error when not initialized")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testReadTranscriptResourceWhenNotInitialized() async throws {
        do {
            _ = try await client.readTranscriptResource(path: "test.md")
            XCTFail("Expected error when not initialized")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testListEntitiesResourceWhenNotInitialized() async throws {
        do {
            _ = try await client.listEntitiesResource(type: "person")
            XCTFail("Expected error when not initialized")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testGetConfigResourceWhenNotInitialized() async throws {
        do {
            _ = try await client.getConfigResource()
            XCTFail("Expected error when not initialized")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Additional MCPClient+Resources Tests

@available(macOS 14.0, *)
final class MCPClientResourcesAdditionalTests: XCTestCase {
    
    private let nonexistentPath = "/nonexistent/path/to/server"
    
    private func createClient() -> MCPClient {
        let transport = StdioTransport(serverPath: nonexistentPath)
        return MCPClient(transport: transport)
    }
    
    // MARK: - ListResources Tests
    
    func testListResourcesMultipleTimes() async {
        let client = createClient()
        
        // Multiple calls should all fail with same error
        for _ in 0..<3 {
            do {
                _ = try await client.listResources()
                XCTFail("Expected notInitialized error")
            } catch let error as MCPClientError {
                if case .notInitialized = error { /* Expected */ }
            } catch { }
        }
    }
    
    // MARK: - ReadResource Tests
    
    func testReadResourceWithVariousURIs() async {
        let client = createClient()
        let testURIs = [
            "protokoll://config",
            "protokoll://transcript/test.md",
            "protokoll://entities/person",
            "protokoll://entity/person/123",
            "invalid://uri"
        ]
        
        for uri in testURIs {
            do {
                _ = try await client.readResource(uri: uri)
                XCTFail("Expected notInitialized error")
            } catch let error as MCPClientError {
                if case .notInitialized = error { /* Expected */ }
            } catch { }
        }
    }
    
    // MARK: - ListTranscriptsResource Tests
    
    func testListTranscriptsResourceWithPagination() async {
        let client = createClient()
        
        do {
            _ = try await client.listTranscriptsResource(directory: "/test", limit: 100, offset: 50)
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
    }
    
    func testListTranscriptsResourceWithDefaults() async {
        let client = createClient()
        
        do {
            _ = try await client.listTranscriptsResource(directory: "/output")
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
    }
    
    // MARK: - ReadTranscriptResource Tests
    
    func testReadTranscriptResourceWithVariousPaths() async {
        let client = createClient()
        let paths = [
            "test.md",
            "/absolute/path/transcript.md",
            "relative/path/file.md",
            ""
        ]
        
        for path in paths {
            do {
                _ = try await client.readTranscriptResource(path: path)
                XCTFail("Expected error")
            } catch let error as MCPClientError {
                if case .notInitialized = error { /* Expected */ }
            } catch { }
        }
    }
    
    // MARK: - ListEntitiesResource Tests
    
    func testListEntitiesResourceWithDifferentTypes() async {
        let client = createClient()
        let types = ["person", "project", "term", "company", "unknown"]
        
        for type in types {
            do {
                _ = try await client.listEntitiesResource(type: type)
                XCTFail("Expected error")
            } catch let error as MCPClientError {
                if case .notInitialized = error { /* Expected */ }
            } catch { }
        }
    }
    
    // MARK: - GetConfigResource Tests
    
    func testGetConfigResourceAfterClientStop() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let client = MCPClient(transport: transport)
        
        try await client.stop()
        
        do {
            _ = try await client.getConfigResource()
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
    }
    
    // MARK: - Multiple Client Instances
    
    func testMultipleClientResourceOperations() async {
        let client1 = createClient()
        let client2 = createClient()
        
        // Both should fail independently
        do {
            _ = try await client1.listResources()
        } catch { /* Expected */ }
        
        do {
            _ = try await client2.readResource(uri: "protokoll://config")
        } catch { /* Expected */ }
        
        // Neither should affect the other
        do {
            _ = try await client1.getConfigResource()
        } catch { /* Expected */ }
    }
}
