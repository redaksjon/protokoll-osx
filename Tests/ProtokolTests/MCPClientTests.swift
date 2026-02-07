import XCTest
import OSLog
@testable import ProtokolLib

@available(macOS 14.0, *)
final class MCPClientTests: XCTestCase {
    
    // Note: MCPClient requires StdioTransport specifically, so we can't easily mock it
    // These tests focus on testing MCPClient with real StdioTransport instances
    // using non-existent server paths to test error cases
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
    
    // Note: Since we can't easily mock StdioTransport, these tests focus on
    // error cases and state management that don't require a running server
    
    // MARK: - Initialization Tests
    
    func testInitialization() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let client = MCPClient(transport: transport)
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    // MARK: - Start Tests
    
    func testStartFailsWhenServerNotFound() async throws {
        do {
            try await client.start()
            XCTFail("Expected start to fail when server not found")
        } catch {
            // Expected - server path doesn't exist
        }
    }
    
    func testStartFailsWhenTransportFails() async throws {
        // Using non-existent path will cause transport to fail
        do {
            try await client.start()
            XCTFail("Expected start to fail")
        } catch {
            // Expected
        }
    }
    
    // MARK: - Stop Tests
    
    func testStopWhenNotStarted() async throws {
        // Should succeed without error
        try await client.stop()
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    func testStopAfterFailedStart() async throws {
        // Should be safe to stop after a failed start
        do {
            try await client.start()
        } catch {
            // Expected
        }
        
        try await client.stop()
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    // MARK: - IsReady Tests
    
    func testIsReadyWhenNotInitialized() async {
        // IsReady should be false when not initialized
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    // MARK: - SendRequest Tests
    
    // Note: Full sendRequest tests require a running server, which is complex to set up
    // These tests focus on error cases that don't require a server
    
    func testSendRequestWhenNotInitialized() async throws {
        do {
            struct TestResponse: Codable {
                let result: String
            }
            _ = try await client.sendRequest(method: "test/method") as TestResponse
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
    
    // MARK: - Capabilities Tests
    
    func testGetCapabilitiesWhenNotInitialized() async {
        let capabilities = await client.getCapabilities()
        XCTAssertNil(capabilities)
    }
    
    func testHasCapabilityWhenNotInitialized() async {
        let hasCapability = await client.hasCapability { _ in true }
        XCTAssertFalse(hasCapability)
    }
    
    // MARK: - MCPClientError Tests
    
    func testMCPClientErrorDescriptions() {
        let notInitializedError = MCPClientError.notInitialized
        XCTAssertNotNil(notInitializedError.errorDescription)
        
        let clientStoppedError = MCPClientError.clientStopped
        XCTAssertNotNil(clientStoppedError.errorDescription)
        
        let serverError = MCPClientError.serverError(code: -32601, message: "Method not found")
        XCTAssertNotNil(serverError.errorDescription)
        
        let noResultError = MCPClientError.noResult
        XCTAssertNotNil(noResultError.errorDescription)
        
        let transportError = MCPClientError.transportError(NSError(domain: "Test", code: 1))
        XCTAssertNotNil(transportError.errorDescription)
        
        let decodingError = MCPClientError.decodingError(NSError(domain: "Test", code: 2))
        XCTAssertNotNil(decodingError.errorDescription)
    }
    
    func testMCPClientErrorDescriptionContent() {
        // Test specific content in error descriptions
        let notInitialized = MCPClientError.notInitialized
        XCTAssertTrue(notInitialized.errorDescription?.contains("not initialized") ?? false)
        
        let clientStopped = MCPClientError.clientStopped
        XCTAssertTrue(clientStopped.errorDescription?.contains("stopped") ?? false)
        
        let serverError = MCPClientError.serverError(code: -32600, message: "Invalid Request")
        XCTAssertTrue(serverError.errorDescription?.contains("-32600") ?? false)
        XCTAssertTrue(serverError.errorDescription?.contains("Invalid Request") ?? false)
        
        let noResult = MCPClientError.noResult
        XCTAssertTrue(noResult.errorDescription?.contains("No result") ?? false)
    }
    
    func testMCPClientErrorAllCases() {
        let errors: [MCPClientError] = [
            .notInitialized,
            .clientStopped,
            .serverError(code: -32600, message: "Test"),
            .noResult,
            .transportError(NSError(domain: "Test", code: 1)),
            .decodingError(NSError(domain: "Test", code: 2))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
}

// MARK: - Additional MCPClient Tests without async setUp/tearDown

@available(macOS 14.0, *)
final class MCPClientAdditionalTests: XCTestCase {
    
    private let nonexistentPath = "/nonexistent/path/to/server"
    
    private func createClient() -> MCPClient {
        let transport = StdioTransport(serverPath: nonexistentPath)
        return MCPClient(transport: transport)
    }
    
    // MARK: - Lifecycle Tests
    
    func testClientLifecycleWithoutStart() async throws {
        let client = createClient()
        
        // Initial state
        var isReady = await client.isReady
        XCTAssertFalse(isReady)
        
        // Stop without start should be safe
        try await client.stop()
        
        // Should still not be ready
        isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    func testMultipleStopsAreSafe() async throws {
        let client = createClient()
        
        try await client.stop()
        try await client.stop()
        try await client.stop()
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    func testStartThenStop() async throws {
        let client = createClient()
        
        // Start should fail (no server)
        do {
            try await client.start()
            XCTFail("Expected start to fail")
        } catch {
            // Expected
        }
        
        // Stop should succeed
        try await client.stop()
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    // MARK: - Capability Tests
    
    func testGetCapabilitiesBeforeInit() async {
        let client = createClient()
        
        let capabilities = await client.getCapabilities()
        XCTAssertNil(capabilities)
    }
    
    func testHasCapabilityBeforeInit() async {
        let client = createClient()
        
        let hasAny = await client.hasCapability { _ in true }
        XCTAssertFalse(hasAny)
    }
    
    func testHasCapabilityAlwaysFalseWhenNotInitialized() async {
        let client = createClient()
        
        // Any capability check should return false
        let check1 = await client.hasCapability { caps in caps.tools != nil }
        let check2 = await client.hasCapability { caps in caps.resources != nil }
        let check3 = await client.hasCapability { caps in caps.prompts != nil }
        
        XCTAssertFalse(check1)
        XCTAssertFalse(check2)
        XCTAssertFalse(check3)
    }
    
    // MARK: - SendRequest Tests
    
    func testSendRequestFailsWhenNotInitialized() async {
        let client = createClient()
        
        struct TestResponse: Codable {
            let result: String
        }
        
        do {
            let _: TestResponse = try await client.sendRequest(method: "test/method")
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }
    
    func testSendRequestWithParamsFailsWhenNotInitialized() async {
        let client = createClient()
        
        struct TestParams: Codable {
            let name: String
        }
        struct TestResponse: Codable {
            let result: String
        }
        
        do {
            let _: TestResponse = try await client.sendRequest(
                method: "test/method",
                params: TestParams(name: "test")
            )
            XCTFail("Expected notInitialized error")
        } catch let error as MCPClientError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }
    
    // MARK: - Multiple Client Tests
    
    func testMultipleClientsAreIndependent() async throws {
        let client1 = createClient()
        let client2 = createClient()
        let client3 = createClient()
        
        // All should be not ready
        let ready1 = await client1.isReady
        let ready2 = await client2.isReady
        let ready3 = await client3.isReady
        
        XCTAssertFalse(ready1)
        XCTAssertFalse(ready2)
        XCTAssertFalse(ready3)
        
        // Stop one shouldn't affect others
        try await client1.stop()
        
        let ready2After = await client2.isReady
        let ready3After = await client3.isReady
        
        XCTAssertFalse(ready2After)
        XCTAssertFalse(ready3After)
    }
    
    // MARK: - Initialization Tests
    
    func testClientInitializationWithCustomLogger() async {
        let transport = StdioTransport(serverPath: nonexistentPath)
        let logger = Logger(subsystem: "test", category: "test")
        let client = MCPClient(transport: transport, logger: logger)
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    // MARK: - Start Failure Tests
    
    func testStartFailsWhenTransportFails() async {
        let client = createClient()
        
        do {
            try await client.start()
            XCTFail("Expected start to fail")
        } catch {
            // Expected - transport can't find server
            let isReady = await client.isReady
            XCTAssertFalse(isReady)
        }
    }
    
    func testStartMultipleTimes() async {
        let client = createClient()
        
        // Multiple start attempts should all fail
        for _ in 0..<3 {
            do {
                try await client.start()
                XCTFail("Expected start to fail")
            } catch {
                // Expected
            }
        }
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    // MARK: - Stop After Start Failure
    
    func testStopAfterMultipleFailedStarts() async throws {
        let client = createClient()
        
        // Try to start multiple times (all fail)
        for _ in 0..<2 {
            do {
                try await client.start()
            } catch { /* Expected */ }
        }
        
        // Stop should clean up regardless
        try await client.stop()
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
        
        let capabilities = await client.getCapabilities()
        XCTAssertNil(capabilities)
    }
    
    // MARK: - Concurrent Operations
    
    func testConcurrentStops() async throws {
        let client = createClient()
        
        // Multiple concurrent stops should be safe
        async let stop1: Void = client.stop()
        async let stop2: Void = client.stop()
        async let stop3: Void = client.stop()
        
        try await stop1
        try await stop2
        try await stop3
        
        let isReady = await client.isReady
        XCTAssertFalse(isReady)
    }
    
    func testConcurrentSendRequests() async {
        let client = createClient()
        
        struct TestResponse: Codable {
            let data: String
        }
        
        // Multiple concurrent requests should all fail
        async let result1: Result<TestResponse, Error> = {
            do {
                return .success(try await client.sendRequest(method: "test"))
            } catch {
                return .failure(error)
            }
        }()
        
        async let result2: Result<TestResponse, Error> = {
            do {
                return .success(try await client.sendRequest(method: "test"))
            } catch {
                return .failure(error)
            }
        }()
        
        let results = await [result1, result2]
        
        for result in results {
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                if let mcpError = error as? MCPClientError {
                    if case .notInitialized = mcpError { /* Expected */ }
                }
            }
        }
    }
    
    // MARK: - Error Content Tests
    
    func testTransportErrorDescription() {
        let underlyingError = NSError(domain: "NetworkError", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"])
        let error = MCPClientError.transportError(underlyingError)
        
        XCTAssertTrue(error.errorDescription?.contains("Connection timeout") ?? false)
    }
    
    func testDecodingErrorDescription() {
        let underlyingError = NSError(domain: "JSONError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        let error = MCPClientError.decodingError(underlyingError)
        
        XCTAssertTrue(error.errorDescription?.contains("Invalid JSON") ?? false)
    }
    
    func testServerErrorWithVaryingCodes() {
        let codes = [-32700, -32600, -32601, -32602, -32603, -32000, -1]
        let messages = ["Parse error", "Invalid Request", "Method not found", "Invalid params", "Internal error", "Server error", "Custom"]
        
        for (code, message) in zip(codes, messages) {
            let error = MCPClientError.serverError(code: code, message: message)
            XCTAssertNotNil(error.errorDescription)
            XCTAssertTrue(error.errorDescription?.contains("\(code)") ?? false)
            XCTAssertTrue(error.errorDescription?.contains(message) ?? false)
        }
    }
}
