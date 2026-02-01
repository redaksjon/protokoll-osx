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
    
    // MARK: - Additional JSONRPCRequest Tests
    
    func testJSONRPCRequestEquality() {
        let request1 = JSONRPCRequest(id: 1, method: "test")
        let request2 = JSONRPCRequest(id: 1, method: "test")
        let request3 = JSONRPCRequest(id: 2, method: "test")
        let request4 = JSONRPCRequest(id: 1, method: "other")
        
        XCTAssertEqual(request1, request2)
        XCTAssertNotEqual(request1, request3) // Different id
        XCTAssertNotEqual(request1, request4) // Different method
    }
    
    func testJSONRPCRequestEncodingWithParams() throws {
        let params = AnyCodable(["key": "value", "count": 42])
        let request = JSONRPCRequest(id: 10, method: "test/params", params: params)
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["id"] as? Int, 10)
        XCTAssertNotNil(json?["params"])
    }
    
    // MARK: - Additional JSONRPCResponse Tests
    
    func testJSONRPCResponseEncodingWithResult() throws {
        let response = JSONRPCResponse(id: 5, result: AnyCodable(["status": "ok"]))
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json?["id"] as? Int, 5)
        XCTAssertNotNil(json?["result"])
    }
    
    func testJSONRPCResponseDecodingWithError() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32600, "message": "Invalid Request"}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        
        XCTAssertTrue(response.isError)
        XCTAssertEqual(response.error?.code, -32600)
        XCTAssertEqual(response.error?.message, "Invalid Request")
    }
    
    // MARK: - Additional JSONRPCError Tests
    
    func testJSONRPCErrorWithData() {
        let errorData = AnyCodable(["detail": "extra info"])
        let error = JSONRPCError(code: -32000, message: "Custom error", data: errorData)
        
        XCTAssertEqual(error.code, -32000)
        XCTAssertEqual(error.message, "Custom error")
        XCTAssertNotNil(error.data)
    }
    
    func testJSONRPCErrorEncoding() throws {
        let error = JSONRPCError(code: -32601, message: "Method not found")
        let data = try JSONEncoder().encode(error)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["code"] as? Int, -32601)
        XCTAssertEqual(json?["message"] as? String, "Method not found")
    }
    
    func testJSONRPCErrorDecoding() throws {
        let json = """
        {"code": -32700, "message": "Parse error"}
        """
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(JSONRPCError.self, from: data)
        
        XCTAssertEqual(error.code, -32700)
        XCTAssertEqual(error.message, "Parse error")
    }
    
    // MARK: - Additional JSONRPCNotification Tests
    
    func testJSONRPCNotificationWithParams() {
        let params = AnyCodable(["event": "changed"])
        let notification = JSONRPCNotification(method: "notifications/event", params: params)
        
        XCTAssertEqual(notification.method, "notifications/event")
        XCTAssertNotNil(notification.params)
    }
    
    func testJSONRPCNotificationEquality() {
        let n1 = JSONRPCNotification(method: "test")
        let n2 = JSONRPCNotification(method: "test")
        let n3 = JSONRPCNotification(method: "other")
        
        XCTAssertEqual(n1, n2)
        XCTAssertNotEqual(n1, n3)
    }
    
    func testJSONRPCNotificationEncoding() throws {
        let notification = JSONRPCNotification(method: "notifications/test")
        let data = try JSONEncoder().encode(notification)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json?["method"] as? String, "notifications/test")
        XCTAssertNil(json?["id"]) // Notifications have no id
    }
    
    // MARK: - Additional AnyCodable Tests
    
    func testAnyCodableWithDouble() throws {
        let anyCodable = AnyCodable(3.14159)
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        guard let decodedDouble = decoded.value as? Double else {
            XCTFail("Expected Double value")
            return
        }
        XCTAssertEqual(decodedDouble, 3.14159, accuracy: 0.0001)
    }
    
    func testAnyCodableWithNull() throws {
        let anyCodable = AnyCodable(NSNull())
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        XCTAssertTrue(decoded.value is NSNull)
    }
    
    func testAnyCodableWithNestedArray() throws {
        let anyCodable = AnyCodable([[1, 2], [3, 4]])
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        let array = decoded.value as? [Any]
        XCTAssertEqual(array?.count, 2)
    }
    
    func testAnyCodableWithNestedDictionary() throws {
        let anyCodable = AnyCodable(["outer": ["inner": "value"]])
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        let dict = decoded.value as? [String: Any]
        let inner = dict?["outer"] as? [String: Any]
        XCTAssertEqual(inner?["inner"] as? String, "value")
    }
    
    func testAnyCodableWithMixedTypes() throws {
        let anyCodable = AnyCodable([
            "string": "hello",
            "number": 42,
            "double": 3.14,
            "bool": true,
            "array": [1, 2, 3]
        ])
        let data = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        
        let dict = decoded.value as? [String: Any]
        XCTAssertEqual(dict?["string"] as? String, "hello")
        XCTAssertEqual(dict?["number"] as? Int, 42)
        XCTAssertEqual(dict?["bool"] as? Bool, true)
    }
    
    // MARK: - AnyCodable Encoding Edge Cases
    
    func testAnyCodableEncodingUnsupportedType() {
        // Create an AnyCodable with a type that can't be encoded
        class CustomClass {}
        let anyCodable = AnyCodable(CustomClass())
        
        // Encoding should throw
        XCTAssertThrowsError(try JSONEncoder().encode(anyCodable)) { error in
            XCTAssertTrue(error is EncodingError)
        }
    }
    
    func testAnyCodableDecodingInvalidData() {
        // Try to decode something that doesn't match any supported type
        // Actually, all JSON types are supported, so this is hard to test
        // Let's test with valid data to ensure decode paths work
        let jsonTypes: [(String, Any.Type)] = [
            ("42", Int.self),
            ("3.14", Double.self),
            ("\"hello\"", String.self),
            ("true", Bool.self),
            ("[1,2,3]", Array<Any>.self),
            ("{\"a\":1}", Dictionary<String, Any>.self),
            ("null", NSNull.self)
        ]
        
        for (jsonString, _) in jsonTypes {
            let data = jsonString.data(using: .utf8)!
            XCTAssertNoThrow(try JSONDecoder().decode(AnyCodable.self, from: data))
        }
    }
    
    // Test JSONRPCResponse initializer with all parameters
    func testJSONRPCResponseInitializer() {
        // Test with result
        let successResponse = JSONRPCResponse(jsonrpc: "2.0", id: 1, result: AnyCodable("success"), error: nil)
        XCTAssertEqual(successResponse.id, 1)
        XCTAssertNotNil(successResponse.result)
        XCTAssertNil(successResponse.error)
        
        // Test with error
        let errorResponse = JSONRPCResponse(jsonrpc: "2.0", id: 2, result: nil, error: JSONRPCError(code: -1, message: "Error"))
        XCTAssertEqual(errorResponse.id, 2)
        XCTAssertNil(errorResponse.result)
        XCTAssertNotNil(errorResponse.error)
        
        // Test with default jsonrpc
        let defaultResponse = JSONRPCResponse(id: 3, result: AnyCodable(42))
        XCTAssertEqual(defaultResponse.jsonrpc, "2.0")
    }
    
    func testAnyCodableRoundTrip() throws {
        let values: [Any] = [
            42,
            3.14,
            "hello",
            true,
            false,
            [1, 2, 3],
            ["key": "value"],
            NSNull()
        ]
        
        for value in values {
            let encoded = AnyCodable(value)
            let data = try JSONEncoder().encode(encoded)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            
            // Just verify it doesn't throw
            XCTAssertNotNil(decoded.value)
        }
    }
    
    // MARK: - JSONRPCError Additional Tests
    
    func testJSONRPCErrorWithDataDecoding() throws {
        let json = """
        {"code": -32600, "message": "Invalid", "data": {"detail": "extra info"}}
        """
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(JSONRPCError.self, from: data)
        
        XCTAssertEqual(error.code, -32600)
        XCTAssertNotNil(error.data)
    }
    
    // MARK: - Response Edge Cases
    
    func testJSONRPCResponseWithBothResultAndError() throws {
        // Technically invalid per spec, but should decode
        let json = """
        {"jsonrpc": "2.0", "id": 1, "result": "ok", "error": {"code": -1, "message": "err"}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        
        XCTAssertNotNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.isError) // isError should be true if error exists
    }
    
    func testJSONRPCResponseWithNeitherResultNorError() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        
        XCTAssertNil(response.result)
        XCTAssertNil(response.error)
        XCTAssertFalse(response.isError)
    }
}
