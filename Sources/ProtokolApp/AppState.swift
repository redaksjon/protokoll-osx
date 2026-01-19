import Foundation
import SwiftUI
import OSLog
import ProtokolLib

class AppState: ObservableObject {
    @Published var showFilePicker = false
    @Published var processingFiles: [ProcessingFile] = []
    @Published var transcripts: [Transcript] = []
    @Published var settings = ProtokolSettings()
    @Published var contextData = ContextData()
    @Published var selectedTab: MainTab = .transcribe
    
    // MCP Client
    private(set) var serverManager: ServerManager?
    private(set) var connectionManager: ConnectionManager?
    @Published var mcpClient: MCPClient?
    @Published var mcpInitialized = false
    @Published var mcpError: String?
    private let logger = Logger(subsystem: "com.protokoll.app", category: "appstate")
    
    enum MainTab: String, CaseIterable {
        case transcribe = "Transcribe"
        case transcripts = "Transcripts"
        case context = "Context"
        case activity = "Activity"
    }
    
    init() {
        // Don't initialize MCP in init - do it later
    }
    
    func initializeMCP() async {
        do {
            logger.info("Initializing MCP client")
            let serverManager = ServerManager()
            let connectionManager = ConnectionManager(serverManager: serverManager)
            
            await MainActor.run {
                self.serverManager = serverManager
                self.connectionManager = connectionManager
            }
            
            // Connect
            let client = try await connectionManager.connect()
            await MainActor.run {
                self.mcpClient = client
                self.mcpInitialized = true
            }
            
            logger.info("MCP client initialized successfully")
        } catch {
            logger.error("Failed to initialize MCP: \(error.localizedDescription)")
            await MainActor.run {
                self.mcpError = error.localizedDescription
            }
        }
    }
    
    func shutdownMCP() async {
        do {
            try await connectionManager?.disconnect()
        } catch {
            logger.error("Error shutting down MCP: \(error.localizedDescription)")
        }
    }
}

struct ProtokolSettings: Codable {
    var protokollPath: String = "/usr/local/bin/protokoll"
    var mcpServerPath: String = NSHomeDirectory() + "/.nvm/versions/node/v24.8.0/bin/protokoll-mcp"
    var inputDirectory: String = NSHomeDirectory() + "/Downloads"
    var outputDirectory: String = NSHomeDirectory() + "/Library/CloudStorage/GoogleDrive-tobrien@discursive.com/My Drive/individual"
    var contextDirectory: String = NSHomeDirectory() + "/Library/CloudStorage/GoogleDrive-tobrien@discursive.com/My Drive/individual/.protokoll"
    var model: String = "gpt-5.2"
    var transcriptionModel: String = "whisper-1"
    var interactive: Bool = false
    var selfReflection: Bool = true
    var verbose: Bool = false
    var openaiApiKey: String = ""
    var mcpEnabled: Bool = true
}

struct ProcessingFile: Identifiable {
    let id = UUID()
    let url: URL
    var status: Status = .pending
    var progress: Double = 0.0
    var output: String = ""
    var error: String?
    
    enum Status {
        case pending
        case transcribing
        case enhancing
        case routing
        case completed
        case failed
    }
}

struct Transcript: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let date: Date
    let filePath: String
    let project: String?
    let duration: String?
    let confidence: Double?
    var content: String
    
    // MCP-specific fields
    let filename: String?
    let time: String?
    let hasRawTranscript: Bool
    
    init(id: UUID = UUID(), title: String, date: Date, filePath: String, 
         project: String? = nil, duration: String? = nil, 
         confidence: Double? = nil, content: String,
         filename: String? = nil, time: String? = nil, hasRawTranscript: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.filePath = filePath
        self.project = project
        self.duration = duration
        self.confidence = confidence
        self.content = content
        self.filename = filename
        self.time = time
        self.hasRawTranscript = hasRawTranscript
    }
    
    /// Create from MCP transcript metadata
    static func from(
        metadata: TranscriptsListResource.TranscriptMetadata,
        content: String = ""
    ) -> Transcript? {
        // Parse date from YYYY-MM-DD format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: metadata.date) else {
            return nil
        }
        
        return Transcript(
            title: metadata.title,
            date: date,
            filePath: metadata.path,
            content: content,
            filename: metadata.filename,
            time: metadata.time,
            hasRawTranscript: false  // Not provided by server resource
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Transcript, rhs: Transcript) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContextData: Codable {
    var people: [Person] = []
    var projects: [Project] = []
    var companies: [Company] = []
    var terms: [Term] = []
}

struct Person: Identifiable, Codable {
    var id: String
    var name: String
    var firstName: String?
    var lastName: String?
    var company: String?
    var role: String?
    var soundsLike: [String]
    var context: String?
}

struct Project: Identifiable, Codable {
    var id: String
    var name: String
    var type: String
    var contextType: String
    var destination: String
    var structure: String
    var explicitPhrases: [String]
    var topics: [String]
    var soundsLike: [String]
    var active: Bool
}

struct Company: Identifiable, Codable {
    var id: String
    var name: String
    var soundsLike: [String]
    var context: String?
}

struct Term: Identifiable, Codable {
    var id: String
    var term: String
    var soundsLike: [String]
    var context: String?
}
