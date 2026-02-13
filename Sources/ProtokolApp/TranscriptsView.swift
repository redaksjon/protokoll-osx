import SwiftUI
import OSLog
import ProtokolLib

struct TranscriptsView: View {
    @EnvironmentObject var appState: AppState
    @State private var transcripts: [Transcript] = []
    @State private var searchText = ""
    @State private var selectedTranscript: Transcript?
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var statusFilter: StatusFilter = .all
    @State private var projectFilter: String = "All Projects"
    @State private var availableProjects: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var currentOffset = 0
    @State private var totalTranscripts = 0
    @FocusState private var detailViewFocused: Bool
    let pageSize = 50
    private let logger = Logger(subsystem: "com.protokoll.app", category: "transcripts")
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case titleAscending = "Title A-Z"
    }
    
    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case initial = "Initial"
        case enhanced = "Enhanced"
        case reviewed = "Reviewed"
        case inProgress = "In Progress"
        case closed = "Closed"
        case archived = "Archived"
        
        var apiValue: String? {
            switch self {
            case .all: return nil
            case .initial: return "initial"
            case .enhanced: return "enhanced"
            case .reviewed: return "reviewed"
            case .inProgress: return "in_progress"
            case .closed: return "closed"
            case .archived: return "archived"
            }
        }
    }
    
    var filteredTranscripts: [Transcript] {
        var filtered = transcripts
        
        if !searchText.isEmpty {
            filtered = filtered.filter { transcript in
                transcript.title.localizedCaseInsensitiveContains(searchText) ||
                transcript.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        if let statusValue = statusFilter.apiValue {
            filtered = filtered.filter { $0.status == statusValue }
        }
        
        // Apply project filter
        if projectFilter != "All Projects" {
            filtered = filtered.filter { $0.project == projectFilter }
        }
        
        switch sortOrder {
        case .dateDescending:
            filtered.sort { $0.date > $1.date }
        case .dateAscending:
            filtered.sort { $0.date < $1.date }
        case .titleAscending:
            filtered.sort { $0.title < $1.title }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search and controls
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search transcripts...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding()
                
                HStack {
                    Text("\(totalTranscripts) transcripts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("Project", selection: $projectFilter) {
                        Text("All Projects").tag("All Projects")
                        ForEach(availableProjects, id: \.self) { project in
                            Text(project).tag(project)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    
                    Picker("Status", selection: $statusFilter) {
                        ForEach(StatusFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                    
                    Button(action: { Task { await loadTranscripts() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Content
                if isLoading && transcripts.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading transcripts...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ErrorView(error: error, onRetry: { Task { await loadTranscripts() } })
                } else if filteredTranscripts.isEmpty {
                    TranscriptEmptyView(searchText: searchText)
                } else {
                    List(filteredTranscripts, selection: $selectedTranscript) { transcript in
                        TranscriptRow(transcript: transcript)
                            .tag(transcript)
                    }
                    
                    // Pagination controls
                    if totalTranscripts > pageSize {
                        PaginationControls(
                            currentOffset: currentOffset,
                            pageSize: pageSize,
                            total: totalTranscripts,
                            onPrevious: previousPage,
                            onNext: nextPage
                        )
                    }
                }
            }
            .frame(minWidth: 300)
            .task {
                await loadTranscripts()
            }
            // Auto-reload when MCP client becomes available (handles race condition
            // where this view appears before MCP initialization completes)
            .onChange(of: appState.mcpInitialized) { _, isInitialized in
                if isInitialized && transcripts.isEmpty {
                    Task { await loadTranscripts() }
                }
            }
        } detail: {
            if let transcript = selectedTranscript {
                TranscriptDetailView(
                    transcript: transcript,
                    onRefresh: { Task { await loadTranscripts() } }
                )
                .id(transcript.id)
                .environmentObject(appState)
                .focusable()
                .focused($detailViewFocused)
                .onAppear {
                    // Automatically focus the detail view when a transcript is selected
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        detailViewFocused = true
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a transcript")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedTranscript) { _, newValue in
            // Focus the detail view whenever a new transcript is selected
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detailViewFocused = true
                }
            }
        }
    }
    
    // MARK: - MCP Integration
    
    private func loadTranscripts(retryCount: Int = 0) async {
        isLoading = true
        error = nil
        
        do {
            // Wait briefly for MCP client if it's still connecting
            var client = appState.mcpClient
            if client == nil {
                // Give MCP initialization a chance (up to 10 seconds)
                for _ in 0..<20 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    client = appState.mcpClient
                    if client != nil { break }
                }
            }
            
            guard let client = client else {
                // Still no client - trigger reconnection and wait
                if retryCount < 1 {
                    logger.info("No MCP client, triggering reconnect...")
                    await MainActor.run { appState.autoReconnect() }
                    for _ in 0..<30 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if appState.mcpClient != nil { break }
                    }
                    await loadTranscripts(retryCount: retryCount + 1)
                    return
                }
                await MainActor.run {
                    error = "MCP client not connected. Check connection status in the sidebar."
                    isLoading = false
                }
                return
            }
            
            // Let the MCP server use its own configured output directory
            // (same approach as the VSCode extension)
            logger.info("Loading transcripts via MCP (server default directory)")
            
            let result = try await client.listTranscriptsResource(
                limit: pageSize,
                offset: currentOffset
            )
            
            logger.info("Loaded \(result.transcripts.count) transcripts (total: \(result.total))")
            
            // Convert to Transcript models
            let loadedTranscripts = result.transcripts.compactMap { metadata in
                Transcript.from(metadata: metadata)
            }
            
            // Extract unique project names for the filter
            let projects = Set(loadedTranscripts.compactMap { $0.project }).sorted()
            
            await MainActor.run {
                transcripts = loadedTranscripts
                totalTranscripts = result.total
                availableProjects = projects
                isLoading = false
            }
        } catch {
            logger.error("Failed to load transcripts: \(error.localizedDescription)")
            
            // For connection errors, silently reconnect and retry
            if isListConnectionError(error) && retryCount < 2 {
                logger.info("Connection error in list view (attempt \(retryCount + 1)), reconnecting silently...")
                await MainActor.run { appState.autoReconnect() }
                
                // Wait for reconnection to complete
                for _ in 0..<30 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if appState.mcpInitialized && appState.mcpClient != nil {
                        break
                    }
                }
                
                await loadTranscripts(retryCount: retryCount + 1)
                return
            }
            
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// Check if an error is a connection error (for list view)
    private func isListConnectionError(_ error: Error) -> Bool {
        let errorMsg = error.localizedDescription.lowercased()
        return errorMsg.contains("session") || 
               errorMsg.contains("connection") ||
               errorMsg.contains("mcp-session-id") ||
               errorMsg.contains("write failed") ||
               errorMsg.contains("client stopped") ||
               errorMsg.contains("not initialized") ||
               errorMsg.contains("404") ||
               errorMsg.contains("400") ||
               errorMsg.contains("refused") ||
               errorMsg.contains("not connected")
    }
    
    private func nextPage() {
        guard currentOffset + pageSize < totalTranscripts else { return }
        currentOffset += pageSize
        Task {
            await loadTranscripts()
        }
    }
    
    private func previousPage() {
        guard currentOffset > 0 else { return }
        currentOffset = max(0, currentOffset - pageSize)
        Task {
            await loadTranscripts()
        }
    }
}

// MARK: - Supporting Views

struct TranscriptEmptyView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No transcripts yet" : "No results found")
                .font(.headline)
                .foregroundColor(.secondary)
            if searchText.isEmpty {
                Text("Process audio files to see transcripts here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to Load Transcripts")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PaginationControls: View {
    let currentOffset: Int
    let pageSize: Int
    let total: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack {
            Text("Showing \(currentOffset + 1)-\(min(currentOffset + pageSize, total)) of \(total)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentOffset == 0)
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .disabled(currentOffset + pageSize >= total)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: String?
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
    
    var statusColor: Color {
        StatusColors.color(for: status)
    }
}

/// Centralized status colors matching the VSCode detail page
enum StatusColors {
    static func color(for status: String?) -> Color {
        guard let status = status else {
            return Color(nsColor: .systemGray)
        }
        switch status {
        case "initial":
            return Color(red: 0x6c/255.0, green: 0x75/255.0, blue: 0x7d/255.0) // #6c757d gray
        case "enhanced":
            return Color(red: 0x17/255.0, green: 0xa2/255.0, blue: 0xb8/255.0) // #17a2b8 cyan/teal
        case "reviewed":
            return Color(red: 0x00/255.0, green: 0x7b/255.0, blue: 0xff/255.0) // #007bff blue
        case "in_progress":
            return Color(red: 0xff/255.0, green: 0xc1/255.0, blue: 0x07/255.0) // #ffc107 yellow
        case "closed":
            return Color(red: 0x28/255.0, green: 0xa7/255.0, blue: 0x45/255.0) // #28a745 green
        case "archived":
            return Color(red: 0x6c/255.0, green: 0x75/255.0, blue: 0x7d/255.0) // #6c757d gray
        default:
            return Color(nsColor: .systemGray)
        }
    }
    
    static func label(for status: String?) -> String {
        guard let status = status else { return "Unknown" }
        switch status {
        case "initial": return "Initial"
        case "enhanced": return "Enhanced"
        case "reviewed": return "Reviewed"
        case "in_progress": return "In Progress"
        case "closed": return "Closed"
        case "archived": return "Archived"
        default: return status.capitalized
        }
    }
    
    static func icon(for status: String?) -> String {
        guard let status = status else { return "questionmark.circle" }
        switch status {
        case "initial": return "pencil.circle"
        case "enhanced": return "sparkles"
        case "reviewed": return "eye"
        case "in_progress": return "arrow.triangle.2.circlepath"
        case "closed": return "checkmark.circle.fill"
        case "archived": return "archivebox"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Transcript Row

struct TranscriptRow: View {
    let transcript: Transcript
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(transcript.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let taskCount = transcript.openTasksCount, taskCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                            Text("\(taskCount)")
                        }
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                    }
                    
                    if let confidence = transcript.confidence {
                        ConfidenceBadge(confidence: confidence)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(formattedDate, systemImage: "calendar")
                    
                    if let duration = transcript.duration {
                        Label(duration, systemImage: "clock")
                    }
                    
                    if let project = transcript.project {
                        Label(project, systemImage: "folder")
                    }
                    
                    if let size = transcript.contentSize {
                        Label(formatSize(size), systemImage: "doc")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        } icon: {
            StatusIndicator(status: transcript.status)
        }
        .padding(.vertical, 4)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transcript.date)
    }
    
    func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1fKB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1fMB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor.opacity(0.2))
            .foregroundColor(confidenceColor)
            .cornerRadius(4)
    }
    
    var confidenceColor: Color {
        if confidence >= 0.85 {
            return .green
        } else if confidence >= 0.70 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String?
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: StatusColors.icon(for: status))
                .font(compact ? .caption2 : .caption)
            Text(StatusColors.label(for: status))
                .font(compact ? .caption2 : .caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 2 : 4)
        .background(StatusColors.color(for: status).opacity(0.2))
        .foregroundColor(StatusColors.color(for: status))
        .cornerRadius(compact ? 4 : 12)
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardShortcutHint: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Transcript Detail View

struct TranscriptDetailView: View {
    @EnvironmentObject var appState: AppState
    let transcript: Transcript
    var onRefresh: (() -> Void)?
    
    @State private var content: String = ""
    @State private var isLoadingContent = true
    @State private var contentError: String?
    @State private var editingTitle = false
    @State private var editedTitle: String = ""
    @State private var editingDate = false
    @State private var editedDate: Date = Date()
    @State private var currentStatus: String?
    @State private var tasks: [TranscriptTask] = []
    @State private var tags: [String] = []
    @State private var entities: TranscriptEntities?
    @State private var isUpdating = false
    @State private var newTaskDescription = ""
    @State private var newTag = ""
    @State private var showAddTask = false
    @State private var showAddTag = false
    @FocusState private var isTagFieldFocused: Bool
    @FocusState private var isTaskFieldFocused: Bool
    
    private let logger = Logger(subsystem: "com.protokoll.app", category: "transcript-detail")
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with title
                headerSection
                
                // Metadata section
                metadataSection
                
                // Tags section
                tagsSection
                
                // Tasks section
                tasksSection
                
                // Entity references section
                entitiesSection
                
                Divider()
                
                // Content
                contentSection
            }
            .padding()
        }
        .task {
            await loadTranscriptContent()
        }
        .overlay {
            if isUpdating {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .overlay(ProgressView())
            }
        }
        .popover(isPresented: $editingDate) {
            VStack(spacing: 16) {
                Text("Change Transcript Date")
                    .font(.headline)
                
                DatePicker(
                    "Select new date",
                    selection: $editedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        editingDate = false
                    }
                    .controlSize(.large)
                    
                    Button("Change Date") {
                        Task { await changeDate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(width: 320)
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // Project badge above title
                if let project = transcript.project {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(project)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Title (editable)
                if editingTitle {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Title", text: $editedTitle)
                            .font(.title)
                            .fontWeight(.bold)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                Task { await updateTitle() }
                            }
                            .onChange(of: editedTitle) { oldValue, newValue in
                                // Remove object replacement character (U+FFFC), newlines, and other non-text characters
                                // that might be inserted by rich text operations or pasting
                                let filtered = newValue
                                    .replacingOccurrences(of: "\u{FFFC}", with: "") // Object replacement character
                                    .replacingOccurrences(of: "\u{200B}", with: "") // Zero-width space
                                    .replacingOccurrences(of: "\u{FEFF}", with: "") // Zero-width no-break space
                                    .replacingOccurrences(of: "\n", with: " ")      // Newlines to spaces
                                    .replacingOccurrences(of: "\r", with: "")       // Carriage returns
                                    .replacingOccurrences(of: "\t", with: " ")      // Tabs to spaces
                                if filtered != newValue {
                                    editedTitle = filtered
                                }
                            }
                        
                        HStack(spacing: 8) {
                            Button("Save (⏎)") {
                                Task { await updateTitle() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("Cancel (Esc)") {
                                editingTitle = false
                            }
                            .controlSize(.small)
                            .keyboardShortcut(.escape, modifiers: [])
                        }
                    }
                } else {
                    HStack(alignment: .center, spacing: 8) {
                        Text(cleanTitle(transcript.title))
                            .font(.title)
                            .fontWeight(.bold)
                            .textSelection(.enabled)
                        
                        Button {
                            editedTitle = cleanTitle(transcript.title)
                            editingTitle = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Edit title (⌘E)")
                        .keyboardShortcut("e", modifiers: .command)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { Task { await loadTranscriptContent() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    KeyboardShortcutHint(key: "⌘R")
                }
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .keyboardShortcut("r", modifiers: .command)
        }
    }
    
    // MARK: - Metadata Section
    
    @ViewBuilder
    var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                // Date (clickable to edit)
                Button(action: {
                    editedDate = transcript.date
                    editingDate = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(formattedDate)
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .opacity(0.5)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Duration
                if let duration = transcript.duration {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Confidence
                if let confidence = transcript.confidence {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                        Text("Confidence: \(Int(confidence * 100))%")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Content size
                if let size = transcript.contentSize {
                    Label(formatSize(size), systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                // Status badge with picker
                HStack(spacing: 8) {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(["initial", "enhanced", "reviewed", "in_progress", "closed", "archived"], id: \.self) { status in
                            Button {
                                Task { await changeStatus(to: status) }
                            } label: {
                                HStack {
                                    Text(StatusColors.label(for: status))
                                    if status == (currentStatus ?? transcript.status) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        StatusBadge(status: currentStatus ?? transcript.status)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Tags Section
    
    @ViewBuilder
    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    showAddTag.toggle()
                    if showAddTag {
                        // Focus the text field when showing it
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTagFieldFocused = true
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add tag (⌘G)")
                .keyboardShortcut("g", modifiers: .command)
            }
            
            if showAddTag {
                HStack {
                    TextField("New tag...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .focused($isTagFieldFocused)
                        .onSubmit {
                            Task { await addTag() }
                        }
                    
                    Button("Add") {
                        Task { await addTag() }
                    }
                    .controlSize(.small)
                    .disabled(newTag.isEmpty)
                    
                    Button("Cancel") {
                        showAddTag = false
                        newTag = ""
                        isTagFieldFocused = false
                    }
                    .controlSize(.small)
                }
            }
            
            if tags.isEmpty && !showAddTag {
                Text("No tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button {
                                Task { await removeTag(tag) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Tasks Section
    
    @ViewBuilder
    var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                let openCount = tasks.filter { $0.status == "open" }.count
                Text("Tasks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if openCount > 0 {
                    Text("\(openCount) open")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button {
                    showAddTask.toggle()
                    if showAddTask {
                        // Focus the text field when showing it
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTaskFieldFocused = true
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add task (⌘K)")
                .keyboardShortcut("k", modifiers: .command)
            }
            
            if showAddTask {
                HStack {
                    TextField("New task description...", text: $newTaskDescription)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .focused($isTaskFieldFocused)
                        .onSubmit {
                            Task { await createTask() }
                        }
                    
                    Button("Add") {
                        Task { await createTask() }
                    }
                    .controlSize(.small)
                    .disabled(newTaskDescription.isEmpty)
                    
                    Button("Cancel") {
                        showAddTask = false
                        newTaskDescription = ""
                        isTaskFieldFocused = false
                    }
                    .controlSize(.small)
                }
            }
            
            if tasks.isEmpty && !showAddTask {
                Text("No tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Open tasks first, then done
                let openTasks = tasks.filter { $0.status == "open" }
                let doneTasks = tasks.filter { $0.status == "done" }
                
                ForEach(openTasks) { task in
                    TaskRowView(task: task, onToggle: {
                        Task { await completeTask(task) }
                    }, onDelete: {
                        Task { await deleteTask(task) }
                    })
                }
                
                if !doneTasks.isEmpty {
                    DisclosureGroup("Completed (\(doneTasks.count))") {
                        ForEach(doneTasks) { task in
                            TaskRowView(task: task, onToggle: {}, onDelete: {
                                Task { await deleteTask(task) }
                            })
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Entities Section
    
    @ViewBuilder
    var entitiesSection: some View {
        if let entities = entities, entities.hasAny {
            VStack(alignment: .leading, spacing: 8) {
                Text("Entity References")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let people = entities.people, !people.isEmpty {
                    entityGroup(title: "People", icon: "person.fill", items: people)
                }
                if let projects = entities.projects, !projects.isEmpty {
                    entityGroup(title: "Projects", icon: "folder.fill", items: projects)
                }
                if let companies = entities.companies, !companies.isEmpty {
                    entityGroup(title: "Companies", icon: "building.2.fill", items: companies)
                }
                if let terms = entities.terms, !terms.isEmpty {
                    entityGroup(title: "Terms", icon: "textformat", items: terms)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    func entityGroup(title: String, icon: String, items: [EntityRef]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 6) {
                ForEach(items) { entity in
                    Text(entity.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Content Section
    
    @ViewBuilder
    var contentSection: some View {
        if isLoadingContent {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading transcript content...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if let error = contentError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Retry") {
                    Task { await loadTranscriptContent() }
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if content.isEmpty {
            Text("No content available")
                .foregroundColor(.secondary)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            Text(content)
                .textSelection(.enabled)
                .font(.body)
                .lineSpacing(4)
        }
    }
    
    // MARK: - Data Loading
    
    func loadTranscriptContent(retryCount: Int = 0) async {
        await MainActor.run {
            isLoadingContent = true
            contentError = nil
        }
        
        do {
            // If MCP client is nil, wait for it (may be reconnecting)
            var client = appState.mcpClient
            if client == nil {
                logger.info("MCP client not available, waiting for reconnection...")
                for _ in 0..<20 { // Wait up to 10 seconds
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    client = appState.mcpClient
                    if client != nil { break }
                }
            }
            
            guard let client = client else {
                // Still no client - trigger reconnection and wait for it
                if retryCount < 1 {
                    logger.info("No MCP client, triggering reconnect and waiting...")
                    await MainActor.run { appState.autoReconnect() }
                    // Wait for reconnection to complete (up to 15 seconds)
                    for _ in 0..<30 {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                        if appState.mcpClient != nil { break }
                    }
                    // Retry after reconnection
                    await loadTranscriptContent(retryCount: retryCount + 1)
                    return
                }
                await MainActor.run {
                    contentError = "MCP client not connected"
                    isLoadingContent = false
                }
                return
            }
            
            // Load the full transcript content via MCP resource
            let transcriptContent = try await client.readTranscriptResource(path: transcript.filePath)
            
            // Parse frontmatter and content from the markdown
            let parsed = parseTranscriptMarkdown(transcriptContent)
            
            await MainActor.run {
                content = parsed.body
                currentStatus = parsed.status ?? transcript.status
                tasks = parsed.tasks
                tags = parsed.tags
                entities = parsed.entities
                isLoadingContent = false
            }
        } catch {
            logger.error("Failed to load transcript content: \(error.localizedDescription)")
            
            // For connection errors, silently reconnect and retry instead of showing error
            if isConnectionError(error) && retryCount < 2 {
                logger.info("Connection error detected (attempt \(retryCount + 1)), reconnecting silently...")
                await MainActor.run { appState.autoReconnect() }
                
                // Wait for reconnection to complete (up to 15 seconds)
                for _ in 0..<30 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    if appState.mcpInitialized && appState.mcpClient != nil {
                        break
                    }
                }
                
                // Retry the load
                await loadTranscriptContent(retryCount: retryCount + 1)
                return
            }
            
            // Non-connection error or all retries exhausted - show error
            await MainActor.run {
                contentError = error.localizedDescription
                isLoadingContent = false
            }
        }
    }
    
    // MARK: - Actions
    
    /// Check if an error is a connection error that should trigger auto-reconnect
    private func isConnectionError(_ error: Error) -> Bool {
        let errorMsg = error.localizedDescription.lowercased()
        return errorMsg.contains("session") || 
               errorMsg.contains("connection") ||
               errorMsg.contains("mcp-session-id") ||
               errorMsg.contains("write failed") ||
               errorMsg.contains("client stopped") ||
               errorMsg.contains("not initialized") ||
               errorMsg.contains("404") ||
               errorMsg.contains("400") ||
               errorMsg.contains("refused") ||
               errorMsg.contains("not connected")
    }
    
    /// Wait for MCP client to be available, returns nil if not available after waiting
    private func waitForClient() async -> MCPClient? {
        if let client = appState.mcpClient {
            return client
        }
        // Wait for client to become available (up to 10 seconds)
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let client = appState.mcpClient { return client }
        }
        return nil
    }
    
    /// Silently reconnect and retry an action
    private func reconnectAndRetry(_ action: @escaping () async -> Void) async {
        logger.info("Connection error, reconnecting silently and retrying...")
        await MainActor.run { appState.autoReconnect() }
        
        // Wait for reconnection to complete (up to 15 seconds)
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if appState.mcpInitialized && appState.mcpClient != nil {
                break
            }
        }
        
        // Retry the action
        await action()
    }
    
    func changeStatus(to newStatus: String, retryCount: Int = 0) async {
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            _ = try await client.callTool(
                name: "protokoll_set_status",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "status": newStatus
                ]
            )
            await MainActor.run {
                currentStatus = newStatus
                isUpdating = false
            }
            onRefresh?()
        } catch {
            logger.error("Failed to change status: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.changeStatus(to: newStatus, retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    func updateTitle(retryCount: Int = 0) async {
        // Clean the title: remove object replacement characters and trim whitespace
        let cleanedTitle = editedTitle
            .replacingOccurrences(of: "\u{FFFC}", with: "") // Object replacement character
            .replacingOccurrences(of: "\u{200B}", with: "") // Zero-width space
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Zero-width no-break space
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedTitle.isEmpty else { return }
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            _ = try await client.callTool(
                name: "protokoll_edit_transcript",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "title": cleanedTitle
                ]
            )
            await MainActor.run {
                editingTitle = false
                isUpdating = false
            }
            onRefresh?()
        } catch {
            logger.error("Failed to update title: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.updateTitle(retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    func changeDate(retryCount: Int = 0) async {
        isUpdating = true
        editingDate = false
        
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            
            // Format date as ISO 8601 (YYYY-MM-DD)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: editedDate)
            
            // Define response structure
            struct ChangeDateResult: Codable {
                let success: Bool
                let moved: Bool
                let originalPath: String
                let outputPath: String
                let message: String
            }
            
            let result: ChangeDateResult = try await client.callToolWithTextResult(
                name: "protokoll_change_transcript_date",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "newDate": dateString
                ]
            )
            
            await MainActor.run {
                isUpdating = false
            }
            
            // Show alert about the move
            if result.moved {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Transcript Date Changed"
                    alert.informativeText = "\(result.message)\n\nThe transcript may no longer appear in the current view."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
            
            // Refresh the list
            onRefresh?()
            
        } catch {
            logger.error("Failed to change date: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.changeDate(retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { 
                isUpdating = false
                
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Failed to Change Date"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    func createTask(retryCount: Int = 0) async {
        guard !newTaskDescription.isEmpty else { return }
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            _ = try await client.callTool(
                name: "protokoll_create_task",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "description": newTaskDescription
                ]
            )
            await MainActor.run {
                newTaskDescription = ""
                showAddTask = false
                isTaskFieldFocused = false
                isUpdating = false
            }
            await loadTranscriptContent()
            onRefresh?()
        } catch {
            logger.error("Failed to create task: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.createTask(retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    func completeTask(_ task: TranscriptTask, retryCount: Int = 0) async {
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            _ = try await client.callTool(
                name: "protokoll_complete_task",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "taskId": task.id
                ]
            )
            await MainActor.run { isUpdating = false }
            await loadTranscriptContent()
            onRefresh?()
        } catch {
            logger.error("Failed to complete task: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.completeTask(task, retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    func deleteTask(_ task: TranscriptTask, retryCount: Int = 0) async {
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            _ = try await client.callTool(
                name: "protokoll_delete_task",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "taskId": task.id
                ]
            )
            await MainActor.run { isUpdating = false }
            await loadTranscriptContent()
            onRefresh?()
        } catch {
            logger.error("Failed to delete task: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.deleteTask(task, retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    func addTag(retryCount: Int = 0) async {
        guard !newTag.isEmpty else { return }
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            var updatedTags = tags
            updatedTags.append(newTag)
            _ = try await client.callTool(
                name: "protokoll_edit_transcript",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "tags": updatedTags
                ]
            )
            await MainActor.run {
                tags = updatedTags
                newTag = ""
                showAddTag = false
                isTagFieldFocused = false
                isUpdating = false
            }
        } catch {
            logger.error("Failed to add tag: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.addTag(retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    func removeTag(_ tag: String, retryCount: Int = 0) async {
        isUpdating = true
        do {
            guard let client = await waitForClient() else {
                await MainActor.run { isUpdating = false }
                return
            }
            var updatedTags = tags
            updatedTags.removeAll { $0 == tag }
            _ = try await client.callTool(
                name: "protokoll_edit_transcript",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "tags": updatedTags
                ]
            )
            await MainActor.run {
                tags = updatedTags
                isUpdating = false
            }
        } catch {
            logger.error("Failed to remove tag: \(error.localizedDescription)")
            if isConnectionError(error) && retryCount < 2 {
                await reconnectAndRetry { await self.removeTag(tag, retryCount: retryCount + 1) }
                return
            }
            await MainActor.run { isUpdating = false }
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transcript.date)
    }
    
    /// Clean title by removing object replacement characters, newlines, and other non-text Unicode
    func cleanTitle(_ title: String) -> String {
        return title
            .replacingOccurrences(of: "\u{FFFC}", with: "") // Object replacement character
            .replacingOccurrences(of: "\u{200B}", with: "") // Zero-width space
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Zero-width no-break space
            .replacingOccurrences(of: "\n", with: " ")      // Newlines to spaces
            .replacingOccurrences(of: "\r", with: "")       // Carriage returns
            .replacingOccurrences(of: "\t", with: " ")      // Tabs to spaces
            .replacingOccurrences(of: "  ", with: " ")      // Collapse double spaces
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1fKB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1fMB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: TranscriptTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.status == "done" ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == "done" ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(task.status == "done")
            
            Text(task.description)
                .font(.caption)
                .strikethrough(task.status == "done")
                .foregroundColor(task.status == "done" ? .secondary : .primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Flow Layout (for tags and entities)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxHeight = max(maxHeight, currentY + rowHeight)
        }
        
        return (CGSize(width: maxWidth, height: maxHeight), positions)
    }
}

// MARK: - Markdown Parsing

struct ParsedTranscript {
    var body: String
    var status: String?
    var tags: [String]
    var tasks: [TranscriptTask]
    var entities: TranscriptEntities?
}

struct TranscriptTask: Identifiable {
    let id: String
    let description: String
    let status: String
    let created: String?
}

struct EntityRef: Identifiable {
    let id: String
    let name: String
}

struct TranscriptEntities {
    var people: [EntityRef]?
    var projects: [EntityRef]?
    var companies: [EntityRef]?
    var terms: [EntityRef]?
    
    var hasAny: Bool {
        (people?.isEmpty == false) ||
        (projects?.isEmpty == false) ||
        (companies?.isEmpty == false) ||
        (terms?.isEmpty == false)
    }
}

/// Parse YAML frontmatter and body from a transcript markdown file
func parseTranscriptMarkdown(_ markdown: String) -> ParsedTranscript {
    var body = markdown
    var status: String?
    var tags: [String] = []
    var tasks: [TranscriptTask] = []
    var entities: TranscriptEntities?
    
    // Check for YAML frontmatter
    if markdown.hasPrefix("---") {
        let parts = markdown.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        if parts.count >= 3 {
            let frontmatter = String(parts[1])
            body = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse status from frontmatter
            for line in frontmatter.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("status:") {
                    status = trimmed.replacingOccurrences(of: "status:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "")
                }
            }
            
            // Parse tags from frontmatter
            tags = parseTags(from: frontmatter)
            
            // Parse tasks from frontmatter
            tasks = parseTasks(from: frontmatter)
        }
    }
    
    // Parse entity references from body
    entities = parseEntities(from: body)
    
    return ParsedTranscript(body: body, status: status, tags: tags, tasks: tasks, entities: entities)
}

/// Parse tags from YAML frontmatter
func parseTags(from frontmatter: String) -> [String] {
    var tags: [String] = []
    var inTags = false
    
    for line in frontmatter.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("tags:") {
            let inline = trimmed.replacingOccurrences(of: "tags:", with: "").trimmingCharacters(in: .whitespaces)
            if inline.hasPrefix("[") {
                // Inline array: tags: [tag1, tag2]
                let cleaned = inline.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                tags = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "") }
                return tags
            }
            inTags = true
            continue
        }
        
        if inTags {
            if trimmed.hasPrefix("- ") {
                let tag = trimmed.replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "")
                tags.append(tag)
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("-") {
                inTags = false
            }
        }
    }
    
    return tags
}

/// Parse tasks from YAML frontmatter
func parseTasks(from frontmatter: String) -> [TranscriptTask] {
    var tasks: [TranscriptTask] = []
    var inTasks = false
    var currentTask: [String: String] = [:]
    
    for line in frontmatter.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed == "tasks:" {
            inTasks = true
            continue
        }
        
        if inTasks {
            if trimmed.hasPrefix("- id:") || trimmed.hasPrefix("- description:") {
                // Start of a new task - save previous if exists
                if !currentTask.isEmpty, let id = currentTask["id"], let desc = currentTask["description"] {
                    tasks.append(TranscriptTask(
                        id: id,
                        description: desc,
                        status: currentTask["status"] ?? "open",
                        created: currentTask["created"]
                    ))
                }
                currentTask = [:]
                let key = trimmed.hasPrefix("- id:") ? "id" : "description"
                let value = trimmed.replacingOccurrences(of: "- \(key):", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "")
                currentTask[key] = value
            } else if trimmed.hasPrefix("id:") || trimmed.hasPrefix("description:") || trimmed.hasPrefix("status:") || trimmed.hasPrefix("created:") || trimmed.hasPrefix("completed:") || trimmed.hasPrefix("changed:") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "")
                    currentTask[key] = value
                }
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("-") && !trimmed.hasPrefix(" ") {
                // End of tasks section
                inTasks = false
                if !currentTask.isEmpty, let id = currentTask["id"], let desc = currentTask["description"] {
                    tasks.append(TranscriptTask(
                        id: id,
                        description: desc,
                        status: currentTask["status"] ?? "open",
                        created: currentTask["created"]
                    ))
                }
                currentTask = [:]
            }
        }
    }
    
    // Don't forget last task
    if !currentTask.isEmpty, let id = currentTask["id"], let desc = currentTask["description"] {
        tasks.append(TranscriptTask(
            id: id,
            description: desc,
            status: currentTask["status"] ?? "open",
            created: currentTask["created"]
        ))
    }
    
    return tasks
}

/// Parse entity references from transcript body
func parseEntities(from body: String) -> TranscriptEntities? {
    // Look for ## Entity References section
    guard let range = body.range(of: "## Entity References") else {
        return nil
    }
    
    let entitySection = String(body[range.lowerBound...])
    // Find the end of the entity section (next ## heading or end of document)
    let sectionEnd = entitySection.range(of: "\n## ", range: entitySection.index(entitySection.startIndex, offsetBy: 5)..<entitySection.endIndex)
    let section = sectionEnd != nil ? String(entitySection[..<sectionEnd!.lowerBound]) : entitySection
    
    var people: [EntityRef] = []
    var projects: [EntityRef] = []
    var companies: [EntityRef] = []
    var terms: [EntityRef] = []
    
    var currentCategory = ""
    
    for line in section.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("### People") { currentCategory = "people" }
        else if trimmed.hasPrefix("### Projects") { currentCategory = "projects" }
        else if trimmed.hasPrefix("### Companies") { currentCategory = "companies" }
        else if trimmed.hasPrefix("### Terms") { currentCategory = "terms" }
        else if trimmed.hasPrefix("- ") {
            // Parse entity ref: - Name (id)  or  - **Name** (id)
            var name = trimmed.replacingOccurrences(of: "- ", with: "")
            name = name.replacingOccurrences(of: "**", with: "")
            
            // Extract ID from parentheses if present
            var id = name
            if let parenRange = name.range(of: " (") {
                let idPart = String(name[parenRange.upperBound...]).replacingOccurrences(of: ")", with: "")
                name = String(name[..<parenRange.lowerBound])
                id = idPart
            }
            
            let ref = EntityRef(id: id, name: name)
            switch currentCategory {
            case "people": people.append(ref)
            case "projects": projects.append(ref)
            case "companies": companies.append(ref)
            case "terms": terms.append(ref)
            default: break
            }
        }
    }
    
    let entities = TranscriptEntities(
        people: people.isEmpty ? nil : people,
        projects: projects.isEmpty ? nil : projects,
        companies: companies.isEmpty ? nil : companies,
        terms: terms.isEmpty ? nil : terms
    )
    
    return entities.hasAny ? entities : nil
}
