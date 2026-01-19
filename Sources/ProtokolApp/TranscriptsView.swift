import SwiftUI
import OSLog
import ProtokolLib

struct TranscriptsView: View {
    @EnvironmentObject var appState: AppState
    @State private var transcripts: [Transcript] = []
    @State private var searchText = ""
    @State private var selectedTranscript: Transcript?
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var isLoading = false
    @State private var error: String?
    @State private var currentOffset = 0
    @State private var totalTranscripts = 0
    let pageSize = 50
    private let logger = Logger(subsystem: "com.protokoll.app", category: "transcripts")
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case titleAscending = "Title A-Z"
    }
    
    var filteredTranscripts: [Transcript] {
        var filtered = transcripts
        
        if !searchText.isEmpty {
            filtered = filtered.filter { transcript in
                transcript.title.localizedCaseInsensitiveContains(searchText) ||
                transcript.content.localizedCaseInsensitiveContains(searchText)
            }
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
                    
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    
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
                    EmptyView(searchText: searchText)
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
        } detail: {
            if let transcript = selectedTranscript {
                TranscriptDetailView(transcript: transcript)
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
    }
    
    // MARK: - MCP Integration
    
    private func loadTranscripts() async {
        isLoading = true
        error = nil
        
        do {
            guard let client = appState.mcpClient else {
                await MainActor.run {
                    error = "MCP client not initialized. Please wait a moment..."
                    isLoading = false
                }
                return
            }
            
            let directory = appState.settings.outputDirectory
            logger.info("Loading transcripts from: \(directory)")
            
            // Use MCP resource to list transcripts
            let result = try await client.listTranscriptsResource(
                directory: directory,
                limit: pageSize,
                offset: currentOffset
            )
            
            logger.info("Loaded \(result.transcripts.count) transcripts (total: \(result.total))")
            
            // Convert to Transcript models
            let loadedTranscripts = result.transcripts.compactMap { metadata in
                Transcript.from(metadata: metadata)
            }
            
            await MainActor.run {
                transcripts = loadedTranscripts
                totalTranscripts = result.total
                isLoading = false
            }
        } catch {
            logger.error("Failed to load transcripts: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
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

struct EmptyView: View {
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

struct TranscriptRow: View {
    let transcript: Transcript
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(transcript.title)
                    .font(.headline)
                    .lineLimit(1)
                
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
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transcript.date)
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

struct TranscriptDetailView: View {
    let transcript: Transcript
    @State private var isEditing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transcript.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            Label(formattedDate, systemImage: "calendar")
                            
                            if let duration = transcript.duration {
                                Label(duration, systemImage: "clock")
                            }
                            
                            if let confidence = transcript.confidence {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Confidence: \(Int(confidence * 100))%")
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Button(action: { openInFinder() }) {
                            Label("Show in Finder", systemImage: "folder")
                        }
                        
                        if let project = transcript.project {
                            Text("Project: \(project)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                Divider()
                
                // Content
                Text(transcript.content)
                    .textSelection(.enabled)
                    .font(.body)
                    .lineSpacing(4)
            }
            .padding()
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transcript.date)
    }
    
    func openInFinder() {
        let url = URL(fileURLWithPath: transcript.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
