import XCTest
import Foundation
@testable import ProtokolLib

/// Live diagnostic tests that connect to a real MCP server at http://127.0.0.1:3001.
/// These tests exercise the exact same code paths as the macOS GUI app.
/// Skip if the server is not running.
@available(macOS 14.0, *)
final class LiveMCPDiagnosticTests: XCTestCase {
    
    var transport: SSETransport!
    var client: MCPClient!
    
    /// Check if the MCP server is actually running before each test
    func isServerRunning() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:3001/mcp") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data("{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"health-check\",\"version\":\"0.0\"}}}".utf8)
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Test 1: SSETransport can connect and get session ID
    
    func testSSETransportConnectsAndGetsSessionId() async throws {
        guard await isServerRunning() else {
            print("⏭ SKIP: MCP server not running at 127.0.0.1:3001")
            return
        }
        
        let transport = SSETransport(serverURL: URL(string: "http://127.0.0.1:3001")!)
        try await transport.start()
        
        let connected = await transport.isConnected
        XCTAssertTrue(connected, "Transport should be connected after start()")
        
        // Send a raw initialize request
        let initMsg = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"diagnostic-test","version":"1.0.0"}}}
        """
        try await transport.send(Data(initMsg.utf8))
        
        // Receive the response
        let responseData = try await transport.receive()
        let responseStr = String(data: responseData, encoding: .utf8) ?? "<not utf8>"
        print("✅ SSETransport initialize response (\(responseData.count) bytes): \(responseStr.prefix(200))")
        
        XCTAssertTrue(responseData.count > 0, "Should get a response")
        XCTAssertTrue(responseStr.contains("protocolVersion"), "Response should contain protocolVersion")
        
        try await transport.stop()
        print("✅ SSETransport test passed")
    }
    
    // MARK: - Test 2: MCPClient can initialize via SSETransport
    
    func testMCPClientInitializesViaSSETransport() async throws {
        guard await isServerRunning() else {
            print("⏭ SKIP: MCP server not running at 127.0.0.1:3001")
            return
        }
        
        let transport = SSETransport(serverURL: URL(string: "http://127.0.0.1:3001")!)
        let client = MCPClient(transport: transport)
        
        // This is the exact call the GUI app makes
        try await client.start()
        
        let ready = await client.isReady
        XCTAssertTrue(ready, "Client should be ready after start()")
        
        let caps = await client.getCapabilities()
        XCTAssertNotNil(caps, "Should have server capabilities")
        print("✅ MCPClient initialized. Capabilities: resources=\(caps?.resources != nil), tools=\(caps?.tools != nil)")
        
        try await client.stop()
        print("✅ MCPClient init test passed")
    }
    
    // MARK: - Test 3: List transcripts (the exact call the GUI makes)
    
    func testListTranscriptsResource() async throws {
        guard await isServerRunning() else {
            print("⏭ SKIP: MCP server not running at 127.0.0.1:3001")
            return
        }
        
        let transport = SSETransport(serverURL: URL(string: "http://127.0.0.1:3001")!)
        let client = MCPClient(transport: transport)
        try await client.start()
        
        // This is the EXACT call TranscriptsView.loadTranscripts() makes
        let result = try await client.listTranscriptsResource(
            limit: 5,
            offset: 0
        )
        
        print("✅ listTranscriptsResource returned:")
        print("   Directory: \(result.directory)")
        print("   Total: \(result.total)")
        print("   Transcripts count: \(result.transcripts.count)")
        
        XCTAssertGreaterThan(result.total, 0, "Should have transcripts")
        XCTAssertGreaterThan(result.transcripts.count, 0, "Should return transcript metadata")
        
        // Check each transcript and try date parsing (the Transcript.from method)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for (i, meta) in result.transcripts.enumerated() {
            let dateOK = dateFormatter.date(from: meta.date) != nil
            let projectName = meta.entities?.projects?.first?.name ?? "none"
            print("   [\(i)] title=\(meta.title), date=\(meta.date) (parseable=\(dateOK)), status=\(meta.status ?? "nil"), tasks=\(meta.openTasksCount ?? -1), size=\(meta.contentSize ?? -1), project=\(projectName)")
            
            if !dateOK {
                print("   ⚠️ Date '\(meta.date)' CANNOT be parsed by DateFormatter(yyyy-MM-dd) — this transcript will be SILENTLY DROPPED by Transcript.from()")
            }
        }
        
        // Now test what the GUI actually does: convert to Transcript models
        let converted = result.transcripts.compactMap { metadata in
            // This is the same code from TranscriptsView.loadTranscripts()
            return convertMetadataToTranscript(metadata)
        }
        
        print("   Converted: \(converted.count) of \(result.transcripts.count) transcripts survived compactMap")
        if converted.count < result.transcripts.count {
            print("   ⚠️ \(result.transcripts.count - converted.count) transcripts were DROPPED (likely bad date format)")
        }
        
        try await client.stop()
        print("✅ listTranscripts test passed")
    }
    
    // MARK: - Test 4: ServerManager + ConnectionManager flow (mirrors AppState.initializeMCP)
    
    func testServerManagerFlow() async throws {
        guard await isServerRunning() else {
            print("⏭ SKIP: MCP server not running at 127.0.0.1:3001")
            return
        }
        
        // This mirrors AppState.initializeMCP() exactly
        let serverURL = URL(string: "http://127.0.0.1:3001")!
        let serverManager = ServerManager(
            serverPath: "",  // Not used when serverURL is set
            serverURL: serverURL,
            config: ServerManagerConfig(enableHealthMonitoring: false)
        )
        let connectionManager = ConnectionManager(serverManager: serverManager)
        
        print("ℹ️ Connecting via ServerManager (same as AppState.initializeMCP)...")
        let client = try await connectionManager.connect()
        
        let ready = await client.isReady
        XCTAssertTrue(ready, "Client should be ready")
        print("✅ ServerManager connected, client ready=\(ready)")
        
        // Now try listing transcripts
        let result = try await client.listTranscriptsResource(limit: 3, offset: 0)
        print("✅ Got \(result.transcripts.count) transcripts (total: \(result.total))")
        
        try await connectionManager.disconnect()
        print("✅ ServerManager flow test passed")
    }
    
    // Helper that mirrors Transcript.from(metadata:)
    private func convertMetadataToTranscript(_ metadata: TranscriptsListResource.TranscriptMetadata) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let _ = formatter.date(from: metadata.date) else {
            return false  // Would return nil from Transcript.from()
        }
        return true
    }
}
