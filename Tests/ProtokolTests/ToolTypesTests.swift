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
    
    func testToolRegistryAllConstants() {
        // Test all tool registry constants exist
        XCTAssertEqual(ToolRegistry.contextStatus, "protokoll_context_status")
        XCTAssertEqual(ToolRegistry.listTranscripts, "protokoll_list_transcripts")
        XCTAssertEqual(ToolRegistry.readTranscript, "protokoll_read_transcript")
        XCTAssertEqual(ToolRegistry.listProjects, "protokoll_list_projects")
        XCTAssertEqual(ToolRegistry.listPeople, "protokoll_list_people")
        XCTAssertEqual(ToolRegistry.listTerms, "protokoll_list_terms")
        XCTAssertEqual(ToolRegistry.processAudio, "protokoll_process_audio")
        XCTAssertEqual(ToolRegistry.addProject, "protokoll_add_project")
        XCTAssertEqual(ToolRegistry.addPerson, "protokoll_add_person")
        XCTAssertEqual(ToolRegistry.addTerm, "protokoll_add_term")
        XCTAssertEqual(ToolRegistry.editTranscript, "protokoll_edit_transcript")
        XCTAssertEqual(ToolRegistry.combineTranscripts, "protokoll_combine_transcripts")
        XCTAssertEqual(ToolRegistry.provideFeedback, "protokoll_provide_feedback")
    }
    
    func testToolRegistryAllDescriptions() {
        // Test all tool registry descriptions
        let allTools = [
            ToolRegistry.contextStatus,
            ToolRegistry.listTranscripts,
            ToolRegistry.readTranscript,
            ToolRegistry.listProjects,
            ToolRegistry.listPeople,
            ToolRegistry.listTerms,
            ToolRegistry.processAudio,
            ToolRegistry.addProject,
            ToolRegistry.addPerson,
            ToolRegistry.addTerm,
            ToolRegistry.editTranscript,
            ToolRegistry.combineTranscripts,
            ToolRegistry.provideFeedback
        ]
        
        for tool in allTools {
            let description = ToolRegistry.description(for: tool)
            XCTAssertNotNil(description, "Tool \(tool) should have a description")
            XCTAssertFalse(description?.isEmpty ?? true, "Description for \(tool) should not be empty")
        }
    }
    
    func testToolRegistryDescriptionForUnknownTool() {
        XCTAssertNil(ToolRegistry.description(for: "unknown_tool_xyz"))
        XCTAssertNil(ToolRegistry.description(for: ""))
        XCTAssertNil(ToolRegistry.description(for: "protokoll_nonexistent"))
    }
    
    func testToolRegistryDescriptionContent() {
        // Test specific description content
        let contextStatusDesc = ToolRegistry.description(for: ToolRegistry.contextStatus)
        XCTAssertTrue(contextStatusDesc?.contains("status") ?? false)
        
        let listTranscriptsDesc = ToolRegistry.description(for: ToolRegistry.listTranscripts)
        XCTAssertTrue(listTranscriptsDesc?.contains("transcripts") ?? false)
        
        let processAudioDesc = ToolRegistry.description(for: ToolRegistry.processAudio)
        XCTAssertTrue(processAudioDesc?.contains("audio") ?? false)
    }
    
    // MARK: - Additional Tool Tests
    
    func testToolWithAllFields() {
        let properties: [String: PropertySchema] = [
            "name": PropertySchema(type: "string", description: "Name field")
        ]
        let schema = ToolInputSchema(type: "object", properties: properties, required: ["name"])
        let tool = Tool(name: "full_tool", description: "A fully-specified tool", inputSchema: schema)
        
        XCTAssertEqual(tool.name, "full_tool")
        XCTAssertEqual(tool.description, "A fully-specified tool")
        XCTAssertEqual(tool.inputSchema.type, "object")
        XCTAssertEqual(tool.inputSchema.required, ["name"])
    }
    
    func testToolInputSchemaEquality() {
        let schema1 = ToolInputSchema(type: "object", required: ["a", "b"])
        let schema2 = ToolInputSchema(type: "object", required: ["a", "b"])
        let schema3 = ToolInputSchema(type: "object", required: ["c"])
        let schema4 = ToolInputSchema(type: "array")
        
        XCTAssertEqual(schema1, schema2)
        XCTAssertNotEqual(schema1, schema3) // Different required
        XCTAssertNotEqual(schema1, schema4) // Different type
    }
    
    // MARK: - PropertySchema Additional Tests
    
    func testPropertySchemaWithItems() {
        let itemsSchema = ItemsSchema(type: "string")
        let schema = PropertySchema(
            type: "array",
            description: "Array of strings",
            items: itemsSchema
        )
        
        XCTAssertEqual(schema.type, "array")
        XCTAssertNotNil(schema.items)
        XCTAssertEqual(schema.items?.type, "string")
    }
    
    func testPropertySchemaWithDefault() {
        let schema = PropertySchema(
            type: "string",
            description: "A string with default",
            default: AnyCodable("default_value")
        )
        
        XCTAssertNotNil(schema.default)
    }
    
    func testPropertySchemaWithAllFields() {
        let schema = PropertySchema(
            type: "array",
            description: "Full schema",
            enum: nil,
            items: ItemsSchema(type: "number"),
            default: AnyCodable([1, 2, 3])
        )
        
        XCTAssertEqual(schema.type, "array")
        XCTAssertNotNil(schema.items)
        XCTAssertNotNil(schema.default)
    }
    
    // MARK: - ContentItem Additional Tests
    
    func testContentItemWithData() {
        let item = ContentItem(type: "image", data: "base64data", mimeType: "image/png")
        
        XCTAssertEqual(item.type, "image")
        XCTAssertEqual(item.data, "base64data")
        XCTAssertEqual(item.mimeType, "image/png")
        XCTAssertNil(item.text)
    }
    
    func testContentItemWithAllFields() {
        let item = ContentItem(
            type: "mixed",
            text: "some text",
            data: "some data",
            mimeType: "application/octet-stream"
        )
        
        XCTAssertNotNil(item.text)
        XCTAssertNotNil(item.data)
        XCTAssertNotNil(item.mimeType)
    }
    
    // MARK: - ListToolsResponse Tests
    
    func testListToolsResponseDecoding() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test_tool",
                    "description": "A test tool",
                    "inputSchema": {"type": "object"}
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ListToolsResponse.self, from: data)
        
        XCTAssertEqual(response.tools.count, 1)
        XCTAssertEqual(response.tools.first?.name, "test_tool")
    }
    
    // MARK: - CallToolResponse Tests
    
    func testCallToolResponseDecoding() throws {
        let json = """
        {
            "content": [
                {"type": "text", "text": "Result"}
            ],
            "isError": false
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(CallToolResponse.self, from: data)
        
        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.content.first?.text, "Result")
        XCTAssertEqual(response.isError, false)
    }
    
    func testCallToolResponseWithError() throws {
        let json = """
        {
            "content": [
                {"type": "text", "text": "Error occurred"}
            ],
            "isError": true
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(CallToolResponse.self, from: data)
        
        XCTAssertEqual(response.isError, true)
    }
}
