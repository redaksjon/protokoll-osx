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
}
