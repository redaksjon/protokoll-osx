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
    @Published var mcpServerStatuses: [UUID: MCPServerConnectionStatus] = [:]
    @Published var pendingEditServerID: UUID?
    @Published var serverSwitchGeneration: UInt64 = 0
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
        self.settings = normalizedSettings(self.settings)
        for server in settings.mcpServers {
            mcpServerStatuses[server.id] = .disconnected
        }
    }
    
    /// Load settings from UserDefaults; falls back to defaults if missing or invalid.
    private static func loadSettings() -> ProtokolSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsStorageKey),
              var decoded = try? JSONDecoder().decode(ProtokolSettings.self, from: data) else {
            return ProtokolSettings.withDefaultServers()
        }
        if decoded.mcpServers.isEmpty {
            decoded.mcpServers = Self.migrateLegacyServers(from: decoded)
        }
        if decoded.activeMCPServerID == nil || !decoded.mcpServers.contains(where: { $0.id == decoded.activeMCPServerID }) {
            decoded.activeMCPServerID = decoded.mcpServers.first?.id
        }
        decoded.mcpServers = decoded.mcpServers.map { server in
            var s = server
            if let keychainToken = KeychainHelper.load(for: s.id) {
                s.apiToken = keychainToken
            }
            return s
        }
        return decoded
    }

    static func migrateLegacyServers(from settings: ProtokolSettings) -> [MCPServerProfile] {
        let localServer = MCPServerProfile(
            name: "Local MCP",
            connectionType: .localStdio,
            serverURL: "",
            serverPath: settings.mcpServerPath,
            apiToken: ""
        )
        let remoteURL = settings.mcpServerURL.isEmpty ? "http://127.0.0.1:3001" : settings.mcpServerURL
        let remoteServer = MCPServerProfile(
            name: "Remote MCP",
            connectionType: .remoteHTTP,
            serverURL: remoteURL,
            serverPath: settings.mcpServerPath,
            apiToken: ""
        )
        return [remoteServer, localServer]
    }
    
    /// Persist current settings to UserDefaults.
    /// Tokens are stored in Keychain separately and stripped from the encoded JSON.
    func persistSettings() {
        settings = normalizedSettings(settings)
        let serverIDs = Set(settings.mcpServers.map(\.id))
        mcpServerStatuses = mcpServerStatuses.filter { serverIDs.contains($0.key) }
        for serverID in serverIDs where mcpServerStatuses[serverID] == nil {
            mcpServerStatuses[serverID] = .disconnected
        }

        for server in settings.mcpServers {
            let token = server.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty {
                KeychainHelper.delete(for: server.id)
            } else {
                KeychainHelper.save(token: token, for: server.id)
            }
        }

        var settingsToEncode = settings
        settingsToEncode.mcpServers = settingsToEncode.mcpServers.map { var s = $0; s.apiToken = ""; return s }
        guard let data = try? JSONEncoder().encode(settingsToEncode) else { return }
        UserDefaults.standard.set(data, forKey: settingsStorageKey)
    }

    func normalizedSettings(_ input: ProtokolSettings) -> ProtokolSettings {
        var normalized = input
        var seenNames = Set<String>()
        var seenAddresses = Set<String>()
        var normalizedServers: [MCPServerProfile] = []

        for server in input.mcpServers {
            var item = server
            item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.name.isEmpty {
                item.name = "Server \(normalizedServers.count + 1)"
            }

            let baseName = item.name
            var candidateName = baseName
            var suffix = 2
            while seenNames.contains(candidateName.lowercased()) {
                candidateName = "\(baseName) \(suffix)"
                suffix += 1
            }
            item.name = candidateName
            seenNames.insert(item.name.lowercased())

            item.serverURL = item.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            item.serverPath = item.serverPath.trimmingCharacters(in: .whitespacesAndNewlines)
            item.apiToken = item.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)

            let addressKey = "\(item.connectionType.rawValue):\(item.connectionType == .remoteHTTP ? item.serverURL.lowercased() : item.serverPath.lowercased())"
            if !addressKey.hasSuffix(":") && !seenAddresses.contains(addressKey) {
                seenAddresses.insert(addressKey)
                normalizedServers.append(item)
            }
        }

        if normalizedServers.isEmpty {
            normalizedServers = Self.migrateLegacyServers(from: input)
        }
        normalized.mcpServers = normalizedServers

        if let active = normalized.activeMCPServerID,
           normalized.mcpServers.contains(where: { $0.id == active }) {
            normalized.activeMCPServerID = active
        } else {
            normalized.activeMCPServerID = normalized.mcpServers.first?.id
        }

        return normalized
    }

    func validateServerProfiles(_ settings: ProtokolSettings) -> String? {
        if settings.mcpServers.isEmpty {
            return "At least one MCP server profile is required."
        }

        var seenNames = Set<String>()
        var seenAddresses = Set<String>()

        for server in settings.mcpServers {
            let trimmedName = server.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                return "Each server must have a display name."
            }
            let loweredName = trimmedName.lowercased()
            if seenNames.contains(loweredName) {
                return "Duplicate server name '\(trimmedName)'. Please use unique names."
            }
            seenNames.insert(loweredName)

            switch server.connectionType {
            case .remoteHTTP:
                let trimmedURL = server.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: trimmedURL),
                      let scheme = url.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      url.host != nil else {
                    return "Server '\(trimmedName)' must use a valid HTTP/HTTPS URL."
                }
                let addressKey = "remote:\(trimmedURL.lowercased())"
                if seenAddresses.contains(addressKey) {
                    return "Duplicate remote MCP URL found: \(trimmedURL)"
                }
                seenAddresses.insert(addressKey)
            case .localStdio:
                let trimmedPath = server.serverPath.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedPath.isEmpty {
                    return "Server '\(trimmedName)' must have a local MCP path."
                }
                let addressKey = "local:\(trimmedPath.lowercased())"
                if seenAddresses.contains(addressKey) {
                    return "Duplicate local MCP path found: \(trimmedPath)"
                }
                seenAddresses.insert(addressKey)
            }
        }

        if let active = settings.activeMCPServerID,
           !settings.mcpServers.contains(where: { $0.id == active }) {
            return "Active server selection is invalid."
        }
        return nil
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
        await initializeMCP(serverID: settings.activeMCPServerID)
    }

    func initializeMCP(serverID: UUID?) async {
        guard let targetServer = resolveServer(serverID: serverID) else {
            await MainActor.run {
                mcpError = "No MCP server is configured. Add one in Settings → Advanced."
            }
            return
        }

        do {
            logger.info("Initializing MCP client")
            await MainActor.run {
                appendMCPLog("[MCP] Connecting...")
                mcpError = nil
                mcpServerStatuses[targetServer.id] = .connecting
            }

            let serverURL: URL?
            switch targetServer.connectionType {
            case .remoteHTTP:
                guard let url = URL(string: targetServer.serverURL), !targetServer.serverURL.isEmpty else {
                    throw NSError(domain: "AppState", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid MCP server URL for \(targetServer.name)"])
                }
                serverURL = url
                logger.info("Using HTTP MCP server: \(targetServer.serverURL)")
                await MainActor.run { appendMCPLog("[MCP] [\(targetServer.name)] Mode: HTTP → \(targetServer.serverURL)") }
            case .localStdio:
                serverURL = nil
                logger.info("Using stdio MCP server: \(targetServer.serverPath)")
                await MainActor.run { appendMCPLog("[MCP] [\(targetServer.name)] Mode: stdio → \(targetServer.serverPath)") }
            }

            let resolvedToken = Self.resolveToken(for: targetServer)
            let serverConfig = ServerManagerConfig(
                maxRestartAttempts: targetServer.maxRetryAttempts
            )
            let serverManager = ServerManager(
                serverPath: targetServer.serverPath,
                serverURL: serverURL,
                apiKey: resolvedToken,
                config: serverConfig
            )
            let connectionManager = ConnectionManager(serverManager: serverManager)

            await MainActor.run {
                self.serverManager = serverManager
                self.connectionManager = connectionManager
                self.settings.activeMCPServerID = targetServer.id
                self.persistSettings()
            }

            // Connect
            let client = try await connectionManager.connect()
            await MainActor.run {
                self.mcpClient = client
                self.mcpInitialized = true
                self.mcpError = nil
                self.mcpServerStatuses[targetServer.id] = .connected
                appendMCPLog("[MCP] [\(targetServer.name)] Connected successfully")
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
                errorDetail = "Cannot connect to MCP server \(targetServer.name) at \(targetServer.connectionType == .remoteHTTP ? targetServer.serverURL : targetServer.serverPath). Is the server running?"
            } else if underlyingDescription.contains("No such file") {
                errorDetail = "MCP server not found at \(targetServer.serverPath). Check Settings → Advanced."
            } else {
                errorDetail = underlyingDescription
            }
            await MainActor.run {
                self.mcpError = errorDetail
                self.mcpServerStatuses[targetServer.id] = .failed
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
            if let activeID = settings.activeMCPServerID {
                mcpServerStatuses[activeID] = .disconnected
            }
            appendMCPLog("[MCP] Disconnected")
        }
    }

    func connectToServer(_ serverID: UUID) async {
        await MainActor.run {
            serverSwitchGeneration &+= 1
            transcripts.removeAll()
            contextData = ContextData()
        }
        await shutdownMCP()
        await initializeMCP(serverID: serverID)
    }

    func disconnectActiveServer() async {
        await MainActor.run {
            serverSwitchGeneration &+= 1
            transcripts.removeAll()
            contextData = ContextData()
        }
        await shutdownMCP()
    }

    func status(for serverID: UUID) -> MCPServerConnectionStatus {
        mcpServerStatuses[serverID] ?? .disconnected
    }

    var activeServer: MCPServerProfile? {
        guard let activeID = settings.activeMCPServerID else { return nil }
        return settings.mcpServers.first(where: { $0.id == activeID })
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
                await initializeMCP(serverID: settings.activeMCPServerID)
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

    private func resolveServer(serverID: UUID?) -> MCPServerProfile? {
        if let serverID, let server = settings.mcpServers.first(where: { $0.id == serverID }) {
            return server
        }
        return settings.mcpServers.first
    }

    static func resolveToken(for server: MCPServerProfile) -> String? {
        if let keychainToken = KeychainHelper.load(for: server.id), !keychainToken.isEmpty {
            return keychainToken
        }
        return server.apiToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
    /// Legacy single-server path used for migration/defaults.
    var mcpServers: [MCPServerProfile] = []
    var activeMCPServerID: UUID?

    static func withDefaultServers() -> ProtokolSettings {
        var settings = ProtokolSettings()
        settings.mcpServers = AppState.migrateLegacyServers(from: settings)
        settings.activeMCPServerID = settings.mcpServers.first?.id
        return settings
    }
}

enum MCPServerConnectionStatus: String {
    case disconnected
    case connecting
    case connected
    case failed
}

struct MCPServerProfile: Identifiable, Codable, Hashable {
    enum ConnectionType: String, Codable, CaseIterable {
        case remoteHTTP
        case localStdio

        var label: String {
            switch self {
            case .remoteHTTP: return "Remote HTTP"
            case .localStdio: return "Local stdio"
            }
        }
    }

    var id: UUID = UUID()
    var name: String
    var connectionType: ConnectionType
    var serverURL: String
    var serverPath: String
    var apiToken: String
    var maxRetryAttempts: Int = 3

    init(
        id: UUID = UUID(),
        name: String,
        connectionType: ConnectionType,
        serverURL: String,
        serverPath: String,
        apiToken: String,
        maxRetryAttempts: Int = 3
    ) {
        self.id = id
        self.name = name
        self.connectionType = connectionType
        self.serverURL = serverURL
        self.serverPath = serverPath
        self.apiToken = apiToken
        self.maxRetryAttempts = maxRetryAttempts
    }

    var displayAddress: String {
        switch connectionType {
        case .remoteHTTP:
            return serverURL.isEmpty ? "No URL configured" : serverURL
        case .localStdio:
            return serverPath
        }
    }
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
