import XCTest
@testable import ProtokolLib

final class ToolTypesTests: XCTestCase {
    
    // MARK: - Tool Tests
    
    func testToolCreation() {
        let schema = ToolInputSchema(type: "object")
        let tool = Tool(
            name: "test_tool",
            description: "A test tool",
            inputSchema: schema
        )
        
        XCTAssertEqual(tool.name, "test_tool")
        XCTAssertEqual(tool.description, "A test tool")
        XCTAssertEqual(tool.id, "test_tool")
    }
    
    func testToolEquality() {
        let schema = ToolInputSchema()
        let tool1 = Tool(name: "tool", description: "desc", inputSchema: schema)
        let tool2 = Tool(name: "tool", description: "desc", inputSchema: schema)
        let tool3 = Tool(name: "other", description: "desc", inputSchema: schema)
        
        XCTAssertEqual(tool1, tool2)
        XCTAssertNotEqual(tool1, tool3)
    }
    
    // MARK: - ToolInputSchema Tests
    
    func testToolInputSchemaDefault() {
        let schema = ToolInputSchema()
        
        XCTAssertEqual(schema.type, "object")
        XCTAssertNil(schema.properties)
        XCTAssertNil(schema.required)
    }
    
    func testToolInputSchemaWithProperties() {
        let properties: [String: PropertySchema] = [
            "name": PropertySchema(type: "string", description: "The name")
        ]
        let schema = ToolInputSchema(
            type: "object",
            properties: properties,
            required: ["name"]
        )
        
        XCTAssertEqual(schema.type, "object")
        XCTAssertEqual(schema.properties?.count, 1)
        XCTAssertEqual(schema.required, ["name"])
    }
    
    // MARK: - PropertySchema Tests
    
    func testPropertySchemaCreation() {
        let schema = PropertySchema(
            type: "string",
            description: "A description",
            enum: ["a", "b", "c"]
        )
        
        XCTAssertEqual(schema.type, "string")
        XCTAssertEqual(schema.description, "A description")
        XCTAssertEqual(schema.enum, ["a", "b", "c"])
    }
    
    func testPropertySchemaEquality() {
        let schema1 = PropertySchema(type: "string", description: "desc")
        let schema2 = PropertySchema(type: "string", description: "desc")
        let schema3 = PropertySchema(type: "number", description: "desc")
        
        XCTAssertEqual(schema1, schema2)
        XCTAssertNotEqual(schema1, schema3)
    }
    
    // MARK: - ItemsSchema Tests
    
    func testItemsSchemaCreation() {
        let schema = ItemsSchema(type: "string")
        
        XCTAssertEqual(schema.type, "string")
    }
    
    func testItemsSchemaEquality() {
        let schema1 = ItemsSchema(type: "string")
        let schema2 = ItemsSchema(type: "string")
        let schema3 = ItemsSchema(type: "number")
        
        XCTAssertEqual(schema1, schema2)
        XCTAssertNotEqual(schema1, schema3)
    }
    
    // MARK: - CallToolParams Tests
    
    func testCallToolParamsCreation() {
        let params = CallToolParams(name: "test_tool")
        
        XCTAssertEqual(params.name, "test_tool")
        XCTAssertNil(params.arguments)
    }
    
    func testCallToolParamsWithArguments() {
        let args: [String: AnyCodable] = [
            "path": AnyCodable("/test/path")
        ]
        let params = CallToolParams(name: "read_file", arguments: args)
        
        XCTAssertEqual(params.name, "read_file")
        XCTAssertNotNil(params.arguments)
    }
    
    // MARK: - ContentItem Tests
    
    func testContentItemText() {
        let item = ContentItem(type: "text", text: "Hello, world!")
        
        XCTAssertEqual(item.type, "text")
        XCTAssertEqual(item.text, "Hello, world!")
        XCTAssertNil(item.data)
    }
    
    func testContentItemEquality() {
        let item1 = ContentItem(type: "text", text: "hello")
        let item2 = ContentItem(type: "text", text: "hello")
        let item3 = ContentItem(type: "text", text: "world")
        
        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }
    
    // MARK: - ToolRegistry Tests
    
    func testToolRegistryConstants() {
        XCTAssertEqual(ToolRegistry.contextStatus, "protokoll_context_status")
        XCTAssertEqual(ToolRegistry.listTranscripts, "protokoll_list_transcripts")
        XCTAssertEqual(ToolRegistry.processAudio, "protokoll_process_audio")
    }
    
    func testToolRegistryDescriptions() {
        XCTAssertNotNil(ToolRegistry.description(for: ToolRegistry.contextStatus))
        XCTAssertNotNil(ToolRegistry.description(for: ToolRegistry.listTranscripts))
        XCTAssertNil(ToolRegistry.description(for: "unknown_tool"))
    }
}
