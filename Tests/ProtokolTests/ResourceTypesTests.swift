import XCTest
@testable import ProtokolLib

final class ResourceTypesTests: XCTestCase {
    
    // MARK: - Resource Tests
    
    func testResourceCreation() {
        let resource = Resource(
            uri: "protokoll://test",
            name: "Test Resource",
            description: "A test resource",
            mimeType: "application/json"
        )
        
        XCTAssertEqual(resource.uri, "protokoll://test")
        XCTAssertEqual(resource.name, "Test Resource")
        XCTAssertEqual(resource.description, "A test resource")
        XCTAssertEqual(resource.mimeType, "application/json")
        XCTAssertEqual(resource.id, "protokoll://test")
    }
    
    func testResourceEquality() {
        let resource1 = Resource(uri: "protokoll://a", name: "A")
        let resource2 = Resource(uri: "protokoll://a", name: "A")
        let resource3 = Resource(uri: "protokoll://b", name: "B")
        
        XCTAssertEqual(resource1, resource2)
        XCTAssertNotEqual(resource1, resource3)
    }
    
    func testResourceEncoding() throws {
        let resource = Resource(
            uri: "protokoll://transcript/test.md",
            name: "Test Transcript",
            mimeType: "text/markdown"
        )
        
        let data = try JSONEncoder().encode(resource)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["uri"] as? String, "protokoll://transcript/test.md")
        XCTAssertEqual(json?["name"] as? String, "Test Transcript")
        XCTAssertEqual(json?["mimeType"] as? String, "text/markdown")
    }
    
    // MARK: - ReadResourceParams Tests
    
    func testReadResourceParamsCreation() {
        let params = ReadResourceParams(uri: "protokoll://config")
        
        XCTAssertEqual(params.uri, "protokoll://config")
    }
    
    // MARK: - ProtokolResourceURI Tests
    
    func testProtokolResourceURITranscript() {
        let uri = ProtokolResourceURI.transcript(path: "/path/to/transcript.md")
        
        XCTAssertEqual(uri.uri, "protokoll://transcript//path/to/transcript.md")
    }
    
    func testProtokolResourceURIEntity() {
        let uri = ProtokolResourceURI.entity(type: "person", id: "john-doe")
        
        XCTAssertEqual(uri.uri, "protokoll://entity/person/john-doe")
    }
    
    func testProtokolResourceURITranscripts() {
        let uri = ProtokolResourceURI.transcripts(
            directory: "/output",
            limit: 50,
            offset: 10
        )
        
        XCTAssertTrue(uri.uri.contains("protokoll://transcripts"))
        XCTAssertTrue(uri.uri.contains("limit=50"))
        XCTAssertTrue(uri.uri.contains("offset=10"))
    }
    
    func testProtokolResourceURITranscriptsWithoutPagination() {
        let uri = ProtokolResourceURI.transcripts(directory: "/output")
        
        XCTAssertTrue(uri.uri.contains("protokoll://transcripts"))
        XCTAssertFalse(uri.uri.contains("limit="))
        XCTAssertFalse(uri.uri.contains("offset="))
    }
    
    func testProtokolResourceURIEntities() {
        let uri = ProtokolResourceURI.entities(type: "project")
        
        XCTAssertEqual(uri.uri, "protokoll://entities/project")
    }
    
    func testProtokolResourceURIConfig() {
        let uri = ProtokolResourceURI.config
        
        XCTAssertEqual(uri.uri, "protokoll://config")
    }
    
    // MARK: - TranscriptsListResource Tests
    
    func testTranscriptsListResourceDecoding() throws {
        let json = """
        {
            "directory": "/output",
            "transcripts": [
                {
                    "path": "/output/2024-01/transcript.md",
                    "filename": "transcript.md",
                    "date": "2024-01-15",
                    "title": "Test Transcript"
                }
            ],
            "pagination": {
                "total": 1,
                "limit": 50,
                "offset": 0,
                "hasMore": false
            }
        }
        """
        let data = json.data(using: .utf8)!
        let resource = try JSONDecoder().decode(TranscriptsListResource.self, from: data)
        
        XCTAssertEqual(resource.directory, "/output")
        XCTAssertEqual(resource.transcripts.count, 1)
        XCTAssertEqual(resource.transcripts.first?.title, "Test Transcript")
        XCTAssertEqual(resource.total, 1)
        XCTAssertFalse(resource.hasMore)
    }
    
    // MARK: - Additional Resource Tests
    
    func testResourceWithMinimalFields() {
        let resource = Resource(uri: "protokoll://test", name: "Test")
        
        XCTAssertEqual(resource.uri, "protokoll://test")
        XCTAssertEqual(resource.name, "Test")
        XCTAssertNil(resource.description)
        XCTAssertNil(resource.mimeType)
    }
    
    // MARK: - ResourceTemplate Tests
    
    func testResourceTemplateDecoding() throws {
        let json = """
        {
            "uriTemplate": "protokoll://entity/{type}/{id}",
            "name": "Entity Template",
            "description": "Access entities by type and id",
            "mimeType": "application/json"
        }
        """
        let data = json.data(using: .utf8)!
        let template = try JSONDecoder().decode(ResourceTemplate.self, from: data)
        
        XCTAssertEqual(template.uriTemplate, "protokoll://entity/{type}/{id}")
        XCTAssertEqual(template.name, "Entity Template")
        XCTAssertEqual(template.description, "Access entities by type and id")
        XCTAssertEqual(template.mimeType, "application/json")
    }
    
    func testResourceTemplateEquality() throws {
        let json1 = "{\"uriTemplate\": \"protokoll://a\", \"name\": \"A\"}"
        let json2 = "{\"uriTemplate\": \"protokoll://a\", \"name\": \"A\"}"
        let json3 = "{\"uriTemplate\": \"protokoll://b\", \"name\": \"B\"}"
        
        let t1 = try JSONDecoder().decode(ResourceTemplate.self, from: json1.data(using: .utf8)!)
        let t2 = try JSONDecoder().decode(ResourceTemplate.self, from: json2.data(using: .utf8)!)
        let t3 = try JSONDecoder().decode(ResourceTemplate.self, from: json3.data(using: .utf8)!)
        
        XCTAssertEqual(t1, t2)
        XCTAssertNotEqual(t1, t3)
    }
    
    // MARK: - ListResourcesResponse Tests
    
    func testListResourcesResponseDecoding() throws {
        let json = """
        {
            "resources": [
                {"uri": "protokoll://config", "name": "Config"}
            ],
            "resourceTemplates": [
                {"uriTemplate": "protokoll://transcript/{path}", "name": "Transcript"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ListResourcesResponse.self, from: data)
        
        XCTAssertEqual(response.resources.count, 1)
        XCTAssertEqual(response.resourceTemplates?.count, 1)
    }
    
    // MARK: - ResourceContent Tests
    
    func testResourceContentDecoding() throws {
        let json = """
        {
            "uri": "protokoll://config",
            "mimeType": "application/json",
            "text": "{\\"hasContext\\": true}"
        }
        """
        let data = json.data(using: .utf8)!
        let content = try JSONDecoder().decode(ResourceContent.self, from: data)
        
        XCTAssertEqual(content.uri, "protokoll://config")
        XCTAssertEqual(content.mimeType, "application/json")
        XCTAssertNotNil(content.text)
        XCTAssertNil(content.blob)
    }
    
    func testResourceContentWithBlob() throws {
        let json = """
        {
            "uri": "protokoll://binary",
            "mimeType": "application/octet-stream",
            "blob": "SGVsbG8gV29ybGQ="
        }
        """
        let data = json.data(using: .utf8)!
        let content = try JSONDecoder().decode(ResourceContent.self, from: data)
        
        XCTAssertNil(content.text)
        XCTAssertEqual(content.blob, "SGVsbG8gV29ybGQ=")
    }
    
    // MARK: - ReadResourceResponse Tests
    
    func testReadResourceResponseDecoding() throws {
        let json = """
        {
            "contents": [
                {"uri": "protokoll://test", "text": "content"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ReadResourceResponse.self, from: data)
        
        XCTAssertEqual(response.contents.count, 1)
        XCTAssertEqual(response.contents.first?.text, "content")
    }
    
    // MARK: - EntitiesListResource Tests
    
    func testEntitiesListResourceDecoding() throws {
        let json = """
        {
            "type": "person",
            "entities": [
                {"id": "1", "name": "John Doe", "uri": "protokoll://entity/person/1"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let resource = try JSONDecoder().decode(EntitiesListResource.self, from: data)
        
        XCTAssertEqual(resource.type, "person")
        XCTAssertEqual(resource.entities.count, 1)
        XCTAssertEqual(resource.entities.first?.name, "John Doe")
    }
    
    // MARK: - ConfigResource Tests
    
    func testConfigResourceDecoding() throws {
        let json = """
        {
            "hasContext": true,
            "contextPath": "/path/to/context",
            "entityCounts": {
                "projects": 5,
                "people": 10,
                "terms": 15,
                "companies": 3
            },
            "resources": ["protokoll://config", "protokoll://transcripts"]
        }
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ConfigResource.self, from: data)
        
        XCTAssertTrue(config.hasContext)
        XCTAssertEqual(config.contextPath, "/path/to/context")
        XCTAssertEqual(config.entityCounts.projects, 5)
        XCTAssertEqual(config.entityCounts.people, 10)
        XCTAssertEqual(config.entityCounts.terms, 15)
        XCTAssertEqual(config.entityCounts.companies, 3)
        XCTAssertEqual(config.resources.count, 2)
    }
    
    // MARK: - TranscriptsListResource Additional Tests
    
    func testTranscriptsListResourceWithFilters() throws {
        let json = """
        {
            "directory": "/output",
            "transcripts": [],
            "pagination": {
                "total": 0,
                "limit": 50,
                "offset": 0,
                "hasMore": false
            },
            "filters": {
                "startDate": "2024-01-01",
                "endDate": "2024-12-31"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let resource = try JSONDecoder().decode(TranscriptsListResource.self, from: data)
        
        XCTAssertNotNil(resource.filters)
        XCTAssertEqual(resource.filters?.startDate, "2024-01-01")
        XCTAssertEqual(resource.filters?.endDate, "2024-12-31")
    }
    
    func testTranscriptsListResourceWithFullMetadata() throws {
        let json = """
        {
            "directory": "/output",
            "transcripts": [
                {
                    "uri": "protokoll://transcript/test.md",
                    "path": "/output/test.md",
                    "filename": "test.md",
                    "date": "2024-01-15",
                    "time": "14:30",
                    "title": "Detailed Test"
                }
            ],
            "pagination": {
                "total": 1,
                "limit": 50,
                "offset": 0,
                "hasMore": false
            }
        }
        """
        let data = json.data(using: .utf8)!
        let resource = try JSONDecoder().decode(TranscriptsListResource.self, from: data)
        
        let transcript = resource.transcripts.first
        XCTAssertEqual(transcript?.uri, "protokoll://transcript/test.md")
        XCTAssertEqual(transcript?.time, "14:30")
    }
}
