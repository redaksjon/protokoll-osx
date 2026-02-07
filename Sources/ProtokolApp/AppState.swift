import Foundation
import SwiftUI
import OSLog
import ProtokolLib

private let settingsStorageKey = "com.protokoll.settings"

class AppState: ObservableObject {
    @Published var showFilePicker = false
    @Published var processingFiles: [ProcessingFile] = []
    @Published var transcripts: [Transcript] = []
    @Published var settings: ProtokolSettings
    @Published var contextData = ContextData()
    @Published var selectedTab: MainTab = .transcribe
    
    // MCP Client
    private(set) var serverManager: ServerManager?
    private(set) var connectionManager: ConnectionManager?
    @Published var mcpClient: MCPClient?
    @Published var mcpInitialized = false
    @Published var mcpError: String?
    /// Rolling log of MCP request/response for debugging (newest last).
    @Published var mcpDebugLog: [String] = []
    private let mcpDebugLogMaxLines = 500
    private let logger = Logger(subsystem: "com.protokoll.app", category: "appstate")
    private var reconnectionTask: Task<Void, Never>?
    private var isReconnecting = false
    
    enum MainTab: String, CaseIterable {
        case transcribe = "Transcribe"
        case transcripts = "Transcripts"
        case context = "Context"
        case activity = "Activity"
    }
    
    init() {
        self.settings = Self.loadSettings()
    }
    
    /// Load settings from UserDefaults; falls back to defaults if missing or invalid.
    private static func loadSettings() -> ProtokolSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsStorageKey),
              var decoded = try? JSONDecoder().decode(ProtokolSettings.self, from: data) else {
            return ProtokolSettings()
        }
        // Migrate: if mcpServerURL is empty (old default), set to new default
        if decoded.mcpServerURL.isEmpty {
            decoded.mcpServerURL = "http://127.0.0.1:3001"
        }
        return decoded
    }
    
    /// Persist current settings to UserDefaults. Call after updating `settings`.
    func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsStorageKey)
    }
    
    func appendMCPLog(_ line: String) {
        mcpDebugLog.append(line)
        if mcpDebugLog.count > mcpDebugLogMaxLines {
            mcpDebugLog.removeFirst(mcpDebugLog.count - mcpDebugLogMaxLines)
        }
    }
    
    func clearMCPLog() {
        mcpDebugLog.removeAll()
    }
    
    func initializeMCP() async {
        do {
            logger.info("Initializing MCP client")
            await MainActor.run {
                appendMCPLog("[MCP] Connecting...")
                mcpError = nil
            }
            
            let serverURL: URL?
            if let urlString = settings.mcpServerURL.nilIfEmpty, let url = URL(string: urlString) {
                serverURL = url
                logger.info("Using HTTP MCP server: \(urlString)")
                await MainActor.run { appendMCPLog("[MCP] Mode: HTTP → \(urlString)") }
            } else {
                serverURL = nil
                logger.info("Using stdio MCP server: \(self.settings.mcpServerPath)")
                await MainActor.run { appendMCPLog("[MCP] Mode: stdio → \(self.settings.mcpServerPath)") }
            }
            
            let serverManager = ServerManager(
                serverPath: settings.mcpServerPath,
                serverURL: serverURL
            )
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
                self.mcpError = nil
                appendMCPLog("[MCP] Connected successfully")
            }
            await client.setDebugLogHandler { [weak self] line in
                Task { @MainActor in
                    self?.appendMCPLog(line)
                }
            }
            logger.info("MCP client initialized successfully")
        } catch {
            logger.error("Failed to initialize MCP: \(error.localizedDescription)")
            let errorDetail: String
            let underlyingDescription = error.localizedDescription
            if underlyingDescription.contains("Connection refused") || underlyingDescription.contains("Could not connect") {
                errorDetail = "Cannot connect to MCP server at \(settings.mcpServerURL.isEmpty ? settings.mcpServerPath : settings.mcpServerURL). Is the server running?"
            } else if underlyingDescription.contains("No such file") {
                errorDetail = "MCP server not found at \(settings.mcpServerPath). Check Settings → Paths."
            } else {
                errorDetail = underlyingDescription
            }
            await MainActor.run {
                self.mcpError = errorDetail
                appendMCPLog("[MCP] Failed: \(errorDetail)")
            }
        }
    }
    
    func shutdownMCP() async {
        // Cancel any ongoing reconnection
        reconnectionTask?.cancel()
        reconnectionTask = nil
        isReconnecting = false
        
        do {
            try await connectionManager?.disconnect()
        } catch {
            logger.error("Error shutting down MCP: \(error.localizedDescription)")
        }
        await MainActor.run {
            mcpClient = nil
            mcpInitialized = false
            serverManager = nil
            connectionManager = nil
            appendMCPLog("[MCP] Disconnected")
        }
    }
    
    /// Automatically reconnect when connection is lost (called by views when they detect errors)
    func autoReconnect() {
        // Don't start multiple reconnection tasks
        guard !isReconnecting else {
            logger.info("Reconnection already in progress")
            return
        }
        
        isReconnecting = true
        logger.info("Starting automatic reconnection")
        
        reconnectionTask = Task {
            await MainActor.run {
                appendMCPLog("[MCP] Connection lost, attempting to reconnect...")
            }
            
            // Try to reconnect with exponential backoff
            for attempt in 1...3 {
                guard !Task.isCancelled else { break }
                
                // Short delay before first attempt, slightly longer for subsequent
                let delay: Double = attempt == 1 ? 0.5 : Double(attempt)
                logger.info("Reconnection attempt \(attempt)/3 after \(delay)s...")
                await MainActor.run {
                    appendMCPLog("[MCP] Reconnect attempt \(attempt)/3 (waiting \(String(format: "%.0f", delay))s)...")
                }
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                guard !Task.isCancelled else { break }
                
                // Always do a full shutdown/reinit - this is the most reliable approach
                // (same as clicking "Reconnect" in settings, which the user confirmed works)
                await shutdownMCP()
                await initializeMCP()
                if mcpInitialized {
                    isReconnecting = false
                    logger.info("Automatic reconnection successful on attempt \(attempt)")
                    return
                } else {
                    logger.warning("Reconnection attempt \(attempt) failed")
                    await MainActor.run {
                        appendMCPLog("[MCP] Attempt \(attempt) failed")
                    }
                }
            }
            
            // All attempts failed
            isReconnecting = false
            await MainActor.run {
                mcpError = "Could not reconnect to MCP server after 3 attempts"
                appendMCPLog("[MCP] Auto-reconnection failed after 3 attempts")
            }
            logger.error("Automatic reconnection failed after 3 attempts")
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
    /// Connect to this MCP server via HTTP/SSE. Defaults to the same URL the VSCode extension uses.
    /// Set to empty string to use stdio (subprocess) mode instead.
    var mcpServerURL: String = "http://127.0.0.1:3001"
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
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
    let status: String?
    let openTasksCount: Int?
    let contentSize: Int?
    
    init(id: UUID = UUID(), title: String, date: Date, filePath: String, 
         project: String? = nil, duration: String? = nil, 
         confidence: Double? = nil, content: String,
         filename: String? = nil, time: String? = nil, hasRawTranscript: Bool = false,
         status: String? = nil, openTasksCount: Int? = nil, contentSize: Int? = nil) {
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
        self.status = status
        self.openTasksCount = openTasksCount
        self.contentSize = contentSize
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
        
        // Extract the first project name from entities
        let projectName = metadata.entities?.projects?.first?.name
        
        return Transcript(
            title: metadata.title,
            date: date,
            filePath: metadata.path,
            project: projectName,
            content: content,
            filename: metadata.filename,
            time: metadata.time,
            hasRawTranscript: false,  // Not provided by server resource
            status: metadata.status,
            openTasksCount: metadata.openTasksCount,
            contentSize: metadata.contentSize
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
