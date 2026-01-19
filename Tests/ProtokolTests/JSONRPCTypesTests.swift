import XCTest
@testable import ProtokolLib

final class JSONRPCTypesTests: XCTestCase {
    
    // MARK: - JSONRPCRequest Tests
    
    func testJSONRPCRequestCreation() {
        let request = JSONRPCRequest(id: 1, method: "test/method")
        
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.id, 1)
        XCTAssertEqual(request.method, "test/method")
        XCTAssertNil(request.params)
    }
    
    func testJSONRPCRequestWithParams() {
        let params = AnyCodable(["key": "value"])
        let request = JSONRPCRequest(id: 42, method: "test/params", params: params)
        
        XCTAssertEqual(request.id, 42)
        XCTAssertEqual(request.method, "test/params")
        XCTAssertNotNil(request.params)
    }
    
    func testJSONRPCRequestEncoding() throws {
        let request = JSONRPCRequest(id: 1, method: "initialize")
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json?["id"] as? Int, 1)
        XCTAssertEqual(json?["method"] as? String, "initialize")
    }
    
    func testJSONRPCRequestDecoding() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 5, "method": "resources/list"}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.id, 5)
        XCTAssertEqual(request.method, "resources/list")
    }
    
    // MARK: - JSONRPCResponse Tests
    
    func testJSONRPCResponseWithResult() {
        let response = JSONRPCResponse(id: 1, result: AnyCodable("success"))
        
        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, 1)
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)
        XCTAssertFalse(response.isError)
    }
    
    func testJSONRPCResponseWithError() {
        let error = JSONRPCError(code: -32600, message: "Invalid Request")
        let response = JSONRPCResponse(id: 1, error: error)
        
        XCTAssertTrue(response.isError)
        XCTAssertEqual(response.error?.code, -32600)
        XCTAssertEqual(response.error?.message, "Invalid Request")
    }
    
    func testJSONRPCResponseDecoding() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1, "result": {"status": "ok"}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        
        XCTAssertEqual(response.id, 1)
        XCTAssertFalse(response.isError)
    }
    
    // MARK: - JSONRPCError Tests
    
    func testJSONRPCErrorCreation() {
        let error = JSONRPCError(code: -32601, message: "Method not found")
        
        XCTAssertEqual(error.code, -32601)
        XCTAssertEqual(error.message, "Method not found")
        XCTAssertNil(error.data)
    }
    
    func testJSONRPCErrorEquality() {
        let error1 = JSONRPCError(code: -32600, message: "Invalid")
        let error2 = JSONRPCError(code: -32600, message: "Invalid")
        let error3 = JSONRPCError(code: -32601, message: "Invalid")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    // MARK: - JSONRPCNotification Tests
    
    func testJSONRPCNotificationCreation() {
        let notification = JSONRPCNotification(method: "notifications/changed")
        
        XCTAssertEqual(notification.jsonrpc, "2.0")
        XCTAssertEqual(notification.method, "notifications/changed")
        XCTAssertNil(notification.params)
    }
    
    // MARK: - AnyCodable Tests
    
    func testAnyCodableWithString() throws {
        let anyCodable = AnyCodable("hello")
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        XCTAssertEqual(decoded.value as? String, "hello")
    }
    
    func testAnyCodableWithInt() throws {
        let anyCodable = AnyCodable(42)
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        XCTAssertEqual(decoded.value as? Int, 42)
    }
    
    func testAnyCodableWithBool() throws {
        let anyCodable = AnyCodable(true)
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        XCTAssertEqual(decoded.value as? Bool, true)
    }
    
    func testAnyCodableWithArray() throws {
        let anyCodable = AnyCodable([1, 2, 3])
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        let array = decoded.value as? [Any]
        XCTAssertEqual(array?.count, 3)
    }
    
    func testAnyCodableWithDictionary() throws {
        let anyCodable = AnyCodable(["name": "test", "value": 123])
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        let dict = decoded.value as? [String: Any]
        XCTAssertEqual(dict?["name"] as? String, "test")
    }
}
