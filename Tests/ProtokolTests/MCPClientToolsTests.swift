import XCTest
@testable import ProtokolLib

/// Tests for MCPClient+Tools extension
///
/// NOTE: These tests avoid async setUp/tearDown to prevent XCTest hanging issues.
/// Transport and client instances are created directly in test methods.
@available(macOS 14.0, *)
final class MCPClientToolsTests: XCTestCase {
    
    private let nonexistentPath = "/nonexistent/path/to/server"
    
    // MARK: - Helper
    
    private func createClient() -> MCPClient {
        let transport = StdioTransport(serverPath: nonexistentPath)
        return MCPClient(transport: transport)
    }
    
    // MARK: - listTools Tests
    
    func testListToolsWhenNotInitialized() async {
        let client = createClient()
        
        do {
            _ = try await client.listTools()
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - callTool Tests
    
    func testCallToolWhenNotInitialized() async {
        let client = createClient()
        
        do {
            _ = try await client.callTool(name: "test_tool")
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testCallToolWithArgumentsWhenNotInitialized() async {
        let client = createClient()
        
        do {
            _ = try await client.callTool(
                name: "test_tool",
                arguments: ["key": "value", "number": 42]
            )
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testCallToolWithEmptyArgumentsWhenNotInitialized() async {
        let client = createClient()
        
        do {
            _ = try await client.callTool(name: "empty_args_tool", arguments: [:])
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testCallToolWithComplexArgumentsWhenNotInitialized() async {
        let client = createClient()
        
        do {
            _ = try await client.callTool(
                name: "complex_tool",
                arguments: [
                    "string": "test",
                    "int": 123,
                    "double": 45.67,
                    "bool": true,
                    "array": [1, 2, 3],
                    "nested": ["key": "value"]
                ]
            )
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - callToolWithTextResult Tests
    
    func testCallToolWithTextResultWhenNotInitialized() async {
        let client = createClient()
        
        struct TestResult: Decodable {
            let message: String
        }
        
        do {
            let _: TestResult = try await client.callToolWithTextResult(name: "test_tool")
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testCallToolWithTextResultWithArgumentsWhenNotInitialized() async {
        let client = createClient()
        
        struct TestResult: Decodable {
            let value: Int
        }
        
        do {
            let _: TestResult = try await client.callToolWithTextResult(
                name: "compute_tool",
                arguments: ["input": 42]
            )
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Multiple Client Instances
    
    func testMultipleClientsIndependent() async {
        let client1 = createClient()
        let client2 = createClient()
        let client3 = createClient()
        
        // All should fail with notInitialized independently
        do {
            _ = try await client1.listTools()
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
        
        do {
            _ = try await client2.callTool(name: "test")
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
        
        do {
            struct R: Decodable { let x: Int }
            let _: R = try await client3.callToolWithTextResult(name: "test")
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
    }
    
    // MARK: - Tool Lifecycle Tests
    
    func testCallToolAfterClientStop() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let client = MCPClient(transport: transport)
        
        // Stop client (even though never started)
        try await client.stop()
        
        // Should still get notInitialized (not clientStopped)
        do {
            _ = try await client.callTool(name: "test")
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected - client was never initialized
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testListToolsAfterClientStop() async throws {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let client = MCPClient(transport: transport)
        
        try await client.stop()
        
        do {
            _ = try await client.listTools()
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Additional Tool Parameter Tests
    
    func testCallToolWithAllArgumentTypes() async {
        let client = createClient()
        
        // Test with various argument types
        do {
            _ = try await client.callTool(
                name: "complex",
                arguments: [
                    "string": "value",
                    "int": 42,
                    "float": 3.14,
                    "bool": true,
                    "null": NSNull(),
                    "array": [1, "two", 3.0],
                    "object": ["nested": "value"]
                ]
            )
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
    }
    
    func testCallToolWithSpecialCharacterName() async {
        let client = createClient()
        
        let specialNames = [
            "tool-with-dashes",
            "tool_with_underscores",
            "tool.with.dots",
            "protokoll_list_transcripts",
            "my/namespaced/tool"
        ]
        
        for name in specialNames {
            do {
                _ = try await client.callTool(name: name)
                XCTFail("Expected error for tool: \(name)")
            } catch let error as MCPClientError {
                if case .notInitialized = error { /* Expected */ }
            } catch { }
        }
    }
    
    func testCallToolWithTextResultVariousTypes() async {
        let client = createClient()
        
        struct StringResult: Decodable { let value: String }
        struct IntResult: Decodable { let count: Int }
        struct ArrayResult: Decodable { let items: [String] }
        
        // Test various decodable types
        do {
            let _: StringResult = try await client.callToolWithTextResult(name: "test")
            XCTFail("Expected error")
        } catch { /* Expected */ }
        
        do {
            let _: IntResult = try await client.callToolWithTextResult(name: "test")
            XCTFail("Expected error")
        } catch { /* Expected */ }
        
        do {
            let _: ArrayResult = try await client.callToolWithTextResult(name: "test")
            XCTFail("Expected error")
        } catch { /* Expected */ }
    }
    
    // MARK: - Concurrent Tool Operations
    
    func testConcurrentToolCalls() async {
        let client = createClient()
        
        // Launch multiple concurrent tool calls
        async let call1 = Task {
            do {
                _ = try await client.callTool(name: "tool1")
            } catch { /* Expected */ }
        }
        
        async let call2 = Task {
            do {
                _ = try await client.callTool(name: "tool2")
            } catch { /* Expected */ }
        }
        
        async let call3 = Task {
            do {
                _ = try await client.listTools()
            } catch { /* Expected */ }
        }
        
        await call1.value
        await call2.value
        await call3.value
    }
    
    // MARK: - Empty/Null Argument Tests
    
    func testCallToolWithNilArguments() async {
        let client = createClient()
        
        // Calling with no arguments (nil)
        do {
            _ = try await client.callTool(name: "no_args")
            XCTFail("Expected error")
        } catch let error as MCPClientError {
            if case .notInitialized = error { /* Expected */ }
        } catch { }
    }
}
