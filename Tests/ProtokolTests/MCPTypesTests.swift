import XCTest
@testable import ProtokolLib

final class MCPTypesTests: XCTestCase {
    
    // MARK: - ClientInfo Tests
    
    func testClientInfoCreation() {
        let info = ClientInfo(name: "TestClient", version: "1.0.0")
        
        XCTAssertEqual(info.name, "TestClient")
        XCTAssertEqual(info.version, "1.0.0")
    }
    
    func testClientInfoEquality() {
        let info1 = ClientInfo(name: "Client", version: "1.0")
        let info2 = ClientInfo(name: "Client", version: "1.0")
        let info3 = ClientInfo(name: "Client", version: "2.0")
        
        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }
    
    func testClientInfoEncoding() throws {
        let info = ClientInfo(name: "Protokoll", version: "1.0.0")
        let data = try JSONEncoder().encode(info)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["name"] as? String, "Protokoll")
        XCTAssertEqual(json?["version"] as? String, "1.0.0")
    }
    
    // MARK: - ClientCapabilities Tests
    
    func testClientCapabilitiesCreation() {
        let capabilities = ClientCapabilities(
            roots: ClientCapabilities.RootsCapability(listChanged: true),
            sampling: nil
        )
        
        XCTAssertTrue(capabilities.roots?.listChanged ?? false)
        XCTAssertNil(capabilities.sampling)
    }
    
    func testClientCapabilitiesEmpty() {
        let capabilities = ClientCapabilities()
        
        XCTAssertNil(capabilities.roots)
        XCTAssertNil(capabilities.sampling)
    }
    
    // MARK: - MCPInitializeRequest Tests
    
    func testMCPInitializeRequestCreation() {
        let request = MCPInitializeRequest(
            protocolVersion: "2024-11-05",
            capabilities: ClientCapabilities(),
            clientInfo: ClientInfo(name: "Test", version: "1.0")
        )
        
        XCTAssertEqual(request.protocolVersion, "2024-11-05")
        XCTAssertEqual(request.clientInfo.name, "Test")
    }
    
    func testMCPInitializeRequestEncoding() throws {
        let request = MCPInitializeRequest(
            protocolVersion: "2024-11-05",
            capabilities: ClientCapabilities(),
            clientInfo: ClientInfo(name: "Protokoll macOS", version: "1.0.0")
        )
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["protocolVersion"] as? String, "2024-11-05")
        
        let clientInfo = json?["clientInfo"] as? [String: Any]
        XCTAssertEqual(clientInfo?["name"] as? String, "Protokoll macOS")
    }
    
    // MARK: - MCPErrorCode Tests
    
    func testMCPErrorCodes() {
        XCTAssertEqual(MCPErrorCode.parseError.rawValue, -32700)
        XCTAssertEqual(MCPErrorCode.invalidRequest.rawValue, -32600)
        XCTAssertEqual(MCPErrorCode.methodNotFound.rawValue, -32601)
        XCTAssertEqual(MCPErrorCode.invalidParams.rawValue, -32602)
        XCTAssertEqual(MCPErrorCode.internalError.rawValue, -32603)
        XCTAssertEqual(MCPErrorCode.serverNotInitialized.rawValue, -32002)
        XCTAssertEqual(MCPErrorCode.unknownError.rawValue, -32001)
    }
    
    // MARK: - Additional ClientCapabilities Tests
    
    func testSamplingCapabilityCreation() {
        let sampling = ClientCapabilities.SamplingCapability()
        XCTAssertNotNil(sampling)
    }
    
    func testRootsCapabilityCreation() {
        let roots = ClientCapabilities.RootsCapability()
        XCTAssertNil(roots.listChanged)
        
        let rootsWithValue = ClientCapabilities.RootsCapability(listChanged: false)
        XCTAssertEqual(rootsWithValue.listChanged, false)
    }
    
    func testClientCapabilitiesWithSampling() {
        let capabilities = ClientCapabilities(
            roots: nil,
            sampling: ClientCapabilities.SamplingCapability()
        )
        
        XCTAssertNil(capabilities.roots)
        XCTAssertNotNil(capabilities.sampling)
    }
    
    func testClientCapabilitiesWithBoth() {
        let capabilities = ClientCapabilities(
            roots: ClientCapabilities.RootsCapability(listChanged: true),
            sampling: ClientCapabilities.SamplingCapability()
        )
        
        XCTAssertNotNil(capabilities.roots)
        XCTAssertNotNil(capabilities.sampling)
        XCTAssertTrue(capabilities.roots?.listChanged ?? false)
    }
    
    // MARK: - ServerCapabilities Tests
    
    func testServerCapabilitiesDecoding() throws {
        let json = """
        {
            "tools": {"listChanged": true},
            "resources": {"subscribe": true, "listChanged": false},
            "prompts": {"listChanged": true}
        }
        """
        let data = json.data(using: .utf8)!
        let capabilities = try JSONDecoder().decode(ServerCapabilities.self, from: data)
        
        XCTAssertNotNil(capabilities.tools)
        XCTAssertEqual(capabilities.tools?.listChanged, true)
        XCTAssertNotNil(capabilities.resources)
        XCTAssertEqual(capabilities.resources?.subscribe, true)
        XCTAssertEqual(capabilities.resources?.listChanged, false)
        XCTAssertNotNil(capabilities.prompts)
        XCTAssertEqual(capabilities.prompts?.listChanged, true)
    }
    
    func testServerCapabilitiesDecodingPartial() throws {
        let json = """
        {
            "tools": {"listChanged": false}
        }
        """
        let data = json.data(using: .utf8)!
        let capabilities = try JSONDecoder().decode(ServerCapabilities.self, from: data)
        
        XCTAssertNotNil(capabilities.tools)
        XCTAssertNil(capabilities.resources)
        XCTAssertNil(capabilities.prompts)
    }
    
    // MARK: - ServerInfo Tests
    
    func testServerInfoDecoding() throws {
        let json = """
        {"name": "TestServer", "version": "2.0.0"}
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(ServerInfo.self, from: data)
        
        XCTAssertEqual(info.name, "TestServer")
        XCTAssertEqual(info.version, "2.0.0")
    }
    
    func testServerInfoEquality() throws {
        let json1 = "{\"name\": \"Server\", \"version\": \"1.0\"}"
        let json2 = "{\"name\": \"Server\", \"version\": \"1.0\"}"
        let json3 = "{\"name\": \"Server\", \"version\": \"2.0\"}"
        
        let info1 = try JSONDecoder().decode(ServerInfo.self, from: json1.data(using: .utf8)!)
        let info2 = try JSONDecoder().decode(ServerInfo.self, from: json2.data(using: .utf8)!)
        let info3 = try JSONDecoder().decode(ServerInfo.self, from: json3.data(using: .utf8)!)
        
        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }
    
    // MARK: - MCPInitializeResponse Tests
    
    func testMCPInitializeResponseDecoding() throws {
        let json = """
        {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {"listChanged": true}},
            "serverInfo": {"name": "protokoll-mcp", "version": "0.0.12"}
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(MCPInitializeResponse.self, from: data)
        
        XCTAssertEqual(response.protocolVersion, "2024-11-05")
        XCTAssertEqual(response.serverInfo.name, "protokoll-mcp")
        XCTAssertEqual(response.serverInfo.version, "0.0.12")
        XCTAssertNotNil(response.capabilities.tools)
    }
}
