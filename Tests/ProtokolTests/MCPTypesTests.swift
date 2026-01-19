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
}
