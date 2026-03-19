import AppKit
import ProtokolLib
import SwiftUI

// MARK: - Identify tasks (MCP)

struct TranscriptIdentifyCandidate: Identifiable, Hashable {
    let id: String
    let taskText: String
    let confidenceBucket: String
    let rationale: String
    let suggestedTags: [String]
}

private struct IdentifyTasksToolResult: Codable {
    struct Candidate: Codable {
        let id: String?
        let taskText: String
        let confidenceBucket: String?
        let rationale: String?
        let suggestedTags: [String]?
    }

    let candidates: [Candidate]?
}

private struct ListProjectsToolResult: Codable {
    struct Project: Codable {
        let id: String
        let name: String
        let active: Bool?
    }

    let projects: [Project]?
}

extension TranscriptsView {

    // MARK: - Context menu (VS Code `view/item/context` parity)

    @ViewBuilder
    func transcriptListContextMenu(for transcript: Transcript) -> some View {
        Button("Show in Detail") {
            selectedTranscript = transcript
        }
        if transcriptListFileExists(transcript) {
            Button("Reveal in Finder") {
                transcriptListRevealInFinder(transcript)
            }
            Button("Open File") {
                transcriptListOpenFile(transcript)
            }
        }
        Divider()
        Button("Copy Original Transcript") {
            Task { await transcriptListCopyVariant(transcript, original: true) }
        }
        Button("Copy Enhanced Transcript") {
            Task { await transcriptListCopyVariant(transcript, original: false) }
        }
        Button("Copy Transcript URL") {
            transcriptListCopyResourceURL(transcript)
        }
        Divider()
        Button("Rename…") {
            listActionRenameTitle = transcript.title
            listActionRenameTranscript = transcript
        }
        Button("Move to Project…") {
            listActionMoveProjects = []
            listActionMoveLoading = false
            listActionMoveTranscript = transcript
        }
        Menu("Change Status") {
            ForEach(TranscriptListStatusMenuOption.options, id: \.id) { opt in
                Button(opt.label) {
                    Task { await transcriptListSetStatus(transcript, to: opt.id) }
                }
            }
        }
        Button("Identify Tasks…") {
            listActionIdentifyCandidates = []
            listActionSelectedCandidateIDs = []
            listActionIdentifyLoading = true
            listActionIdentifyTranscript = transcript
        }
        Divider()
        Button("Transfer to Another Server…") {
            transcriptListShowTransferInfo()
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    func transcriptListRenameSheet(transcript: Transcript) -> some View {
        NavigationStack {
            Form {
                TextField("Title", text: $listActionRenameTitle)
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle("Rename Transcript")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { listActionRenameTranscript = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await transcriptListCommitRename(for: transcript) }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(listActionRenameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 140)
    }

    @ViewBuilder
    func transcriptListMoveProjectSheet(transcript: Transcript) -> some View {
        NavigationStack {
            Group {
                if listActionMoveLoading && listActionMoveProjects.isEmpty {
                    ProgressView("Loading projects…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if listActionMoveProjects.isEmpty {
                    ContentUnavailableView(
                        "No projects",
                        systemImage: "folder",
                        description: Text("No active projects returned by the server.")
                    )
                } else {
                    List(listActionMoveProjects, id: \.id) { project in
                        Button {
                            Task {
                                await transcriptListApplyMoveToProject(
                                    transcript,
                                    projectId: project.id,
                                    projectName: project.name
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                Text(project.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Move to Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { listActionMoveTranscript = nil }
                }
            }
            .task {
                await transcriptListFetchProjectsForMove()
            }
        }
        .frame(minWidth: 380, minHeight: 320)
    }

    @ViewBuilder
    func transcriptListIdentifyTasksSheet(transcript: Transcript) -> some View {
        NavigationStack {
            Group {
                if listActionIdentifyLoading && listActionIdentifyCandidates.isEmpty {
                    ProgressView("Finding tasks…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if listActionIdentifyCandidates.isEmpty {
                    ContentUnavailableView(
                        "No tasks found",
                        systemImage: "checklist",
                        description: Text("Try another transcript or add tasks manually in the detail view.")
                    )
                } else {
                    List(listActionIdentifyCandidates, selection: $listActionSelectedCandidateIDs) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.taskText)
                            Text("\(candidate.confidenceBucket.uppercased()) · \(candidate.rationale)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(candidate.id)
                    }
                }
            }
            .navigationTitle("Identify Tasks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { listActionIdentifyTranscript = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Selected") {
                        Task { await transcriptListCreateSelectedTasks(for: transcript) }
                    }
                    .disabled(listActionSelectedCandidateIDs.isEmpty)
                }
            }
            .task {
                await transcriptListFetchIdentifyCandidates(for: transcript)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - File / pasteboard

    func transcriptListFileExists(_ transcript: Transcript) -> Bool {
        FileManager.default.fileExists(atPath: transcript.filePath)
    }

    func transcriptListRevealInFinder(_ transcript: Transcript) {
        let url = URL(fileURLWithPath: transcript.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func transcriptListOpenFile(_ transcript: Transcript) {
        let url = URL(fileURLWithPath: transcript.filePath)
        NSWorkspace.shared.open(url)
    }

    func transcriptListCopyResourceURL(_ transcript: Transcript) {
        let trimmed = transcript.resourceURI?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let uri = trimmed.isEmpty ? ProtokolResourceURI.transcript(path: transcript.filePath).uri : trimmed
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uri, forType: .string)
        transcriptListInform(title: "Copied", message: "Transcript URL copied to the clipboard.")
    }

    func transcriptListBuildClipboardBlock(
        _ data: TranscriptContentResource,
        original: Bool,
        fallbackStatus: String?
    ) -> String {
        let title = data.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? data.path.split(separator: "/").last.map(String.init) ?? "Untitled Transcript"
        let date = data.metadata.date?.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = data.metadata.time?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateTime = [date, time].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " ").nilIfEmpty
            ?? data.path
        let tags: String
        if let t = data.metadata.tags, !t.isEmpty {
            tags = t.joined(separator: ", ")
        } else {
            tags = "None"
        }
        let status = data.metadata.status ?? fallbackStatus ?? "unknown"
        let body: String
        if original {
            let raw = data.rawTranscript?.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            body = raw ?? data.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            body = data.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return [
            "## \(title)",
            "",
            "**Date/Time:** \(dateTime)",
            "**Tags:** \(tags)",
            "**Status:** \(status)",
            "",
            body,
        ].joined(separator: "\n")
    }

    func transcriptListCopyVariant(_ transcript: Transcript, original: Bool) async {
        await transcriptListWithClient { client in
            let data = try await client.readTranscriptResource(path: transcript.filePath)
            let block = transcriptListBuildClipboardBlock(data, original: original, fallbackStatus: transcript.status)
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(block, forType: .string)
            }
            let label = original ? "Original" : "Enhanced"
            await MainActor.run {
                transcriptListInform(title: "Copied", message: "\(label) transcript copied to the clipboard.")
            }
        }
    }

    // MARK: - MCP actions

    func transcriptListCommitRename(for transcript: Transcript) async {
        let trimmed = listActionRenameTitle
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await transcriptListWithClient { client in
            _ = try await client.callTool(
                name: ToolRegistry.editTranscript,
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "title": trimmed,
                ]
            )
            await MainActor.run {
                listActionRenameTranscript = nil
            }
            await loadTranscripts()
        }
    }

    func transcriptListSetStatus(_ transcript: Transcript, to status: String) async {
        await transcriptListWithClient { client in
            _ = try await client.callTool(
                name: ToolRegistry.editTranscript,
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "status": status,
                ]
            )
            await loadTranscripts()
        }
    }

    func transcriptListFetchProjectsForMove() async {
        await MainActor.run {
            listActionMoveLoading = true
        }
        await transcriptListWithClient { client in
            let args = transcriptListProjectsToolArguments()
            let result: ListProjectsToolResult = try await client.callToolWithTextResult(
                name: ToolRegistry.listProjects,
                arguments: args
            )
            let active = (result.projects ?? []).filter { $0.active != false }
            let rows = active.map { (id: $0.id, name: $0.name) }
            await MainActor.run {
                listActionMoveProjects = rows
                listActionMoveLoading = false
            }
        }
        await MainActor.run {
            if listActionMoveLoading {
                listActionMoveLoading = false
            }
        }
    }

    func transcriptListApplyMoveToProject(
        _ transcript: Transcript,
        projectId: String,
        projectName: String
    ) async {
        await transcriptListWithClient { client in
            _ = try await client.callTool(
                name: ToolRegistry.editTranscript,
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "projectId": projectId,
                ]
            )
            await MainActor.run {
                listActionMoveTranscript = nil
            }
            await loadTranscripts()
            await MainActor.run {
                transcriptListInform(
                    title: "Moved",
                    message: "Transcript moved to project “\(projectName)”."
                )
            }
        }
    }

    func transcriptListFetchIdentifyCandidates(for transcript: Transcript) async {
        await MainActor.run {
            listActionIdentifyLoading = true
            listActionIdentifyCandidates = []
            listActionSelectedCandidateIDs = []
        }
        await transcriptListWithClient { client in
            let result: IdentifyTasksToolResult = try await client.callToolWithTextResult(
                name: "protokoll_identify_tasks_from_transcript",
                arguments: [
                    "transcriptPath": transcript.filePath,
                    "maxCandidates": 25,
                    "includeTagSuggestions": true,
                ]
            )
            let mapped: [TranscriptIdentifyCandidate] = (result.candidates ?? []).enumerated().map { index, c in
                let id = c.id?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "candidate-\(index)-\(UUID().uuidString)"
                return TranscriptIdentifyCandidate(
                    id: id,
                    taskText: c.taskText,
                    confidenceBucket: c.confidenceBucket ?? "unknown",
                    rationale: c.rationale ?? "",
                    suggestedTags: c.suggestedTags ?? []
                )
            }
            await MainActor.run {
                listActionIdentifyCandidates = mapped
                listActionIdentifyLoading = false
            }
            if mapped.isEmpty {
                await MainActor.run {
                    transcriptListInform(
                        title: "Identify Tasks",
                        message: "No task candidates were suggested for this transcript."
                    )
                    listActionIdentifyTranscript = nil
                }
            }
        }
        await MainActor.run {
            if listActionIdentifyLoading {
                listActionIdentifyLoading = false
            }
        }
    }

    func transcriptListCreateSelectedTasks(for transcript: Transcript) async {
        let selected = listActionIdentifyCandidates.filter { listActionSelectedCandidateIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        await transcriptListWithClient { client in
            let snapshot = try await client.readTranscriptResource(path: transcript.filePath)
            var existingDescriptions = (snapshot.metadata.tasks ?? []).map(\.description)
            var created = 0
            var blocked = 0

            for candidate in selected {
                let text = candidate.taskText
                let normalizedNew = transcriptListNormalizeForSimilarity(text)
                let isDup = existingDescriptions.contains { existingDesc in
                    transcriptListSimilarity(
                        normalizedNew,
                        transcriptListNormalizeForSimilarity(existingDesc)
                    ) >= 0.75
                }
                if isDup {
                    blocked += 1
                    continue
                }
                _ = try await client.callTool(
                    name: "protokoll_create_task",
                    arguments: [
                        "transcriptPath": transcript.filePath,
                        "description": text,
                    ]
                )
                existingDescriptions.append(text)
                created += 1
            }

            await MainActor.run {
                listActionIdentifyTranscript = nil
            }
            await loadTranscripts()

            let msg =
                "Created \(created) task\(created == 1 ? "" : "s")"
                + (blocked > 0 ? " (\(blocked) duplicate\(blocked == 1 ? "" : "s") skipped)" : "")
            await MainActor.run {
                transcriptListInform(title: "Tasks", message: msg)
            }

            let tagUnion = Array(
                Set(selected.flatMap(\.suggestedTags).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            )
            if !tagUnion.isEmpty {
                let latest = try await client.readTranscriptResource(path: transcript.filePath)
                let currentTags = latest.metadata.tags ?? []
                await MainActor.run {
                    transcriptListOfferSuggestedTags(
                        tags: tagUnion,
                        transcript: transcript,
                        currentTags: currentTags
                    )
                }
            }
        }
    }

    /// Presents tags alert on MainActor, then applies via MCP.
    @MainActor
    func transcriptListOfferSuggestedTags(
        tags: [String],
        transcript: Transcript,
        currentTags: [String]
    ) {
        let alert = NSAlert()
        alert.messageText = "Apply suggested tags?"
        alert.informativeText = tags.joined(separator: ", ")
        alert.addButton(withTitle: "Add Tags")
        alert.addButton(withTitle: "Skip")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        Task {
            await transcriptListWithClient { client in
                var merged = currentTags
                for t in tags where !merged.contains(t) {
                    merged.append(t)
                }
                _ = try await client.callTool(
                    name: ToolRegistry.editTranscript,
                    arguments: [
                        "transcriptPath": transcript.filePath,
                        "tags": merged,
                    ]
                )
                await loadTranscripts()
            }
        }
    }

    func transcriptListShowTransferInfo() {
        let alert = NSAlert()
        alert.messageText = "Transfer to another server"
        alert.informativeText =
            "Cross-server transfer needs the transcript content on one connection and a second active connection to the target server. The macOS app connects to one MCP server at a time — use the VS Code extension to move or copy transcripts between servers, or export from one server and reconnect to import on another."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Internals

    func transcriptListProjectsToolArguments() -> [String: Any] {
        if appState.activeServer?.connectionType == .localStdio {
            let ctx = appState.settings.contextDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ctx.isEmpty {
                return ["contextDirectory": ctx]
            }
        }
        return [:]
    }

    func transcriptListWithClient(_ work: (MCPClient) async throws -> Void) async {
        var client = appState.mcpClient
        if client == nil {
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                client = appState.mcpClient
                if client != nil { break }
            }
        }
        guard let client else {
            await MainActor.run {
                transcriptListInform(title: "Not connected", message: "Connect to an MCP server in the sidebar first.")
            }
            return
        }
        do {
            try await work(client)
        } catch {
            await MainActor.run {
                transcriptListInform(title: "Error", message: error.localizedDescription)
            }
        }
    }

    func transcriptListInform(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func transcriptListNormalizeForSimilarity(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 }
    }

    func transcriptListSimilarity(_ aTokens: [String], _ bTokens: [String]) -> Double {
        let a = Set(aTokens)
        let b = Set(bTokens)
        if a.isEmpty || b.isEmpty { return 0 }
        let overlap = a.intersection(b).count
        return Double(overlap) / Double(max(a.count, b.count))
    }
}

// MARK: - Status options (VS Code changeTranscriptsStatus)

private struct TranscriptListStatusMenuOption: Identifiable {
    let id: String
    let label: String

    static let options: [TranscriptListStatusMenuOption] = [
        TranscriptListStatusMenuOption(id: "initial", label: "📝 Initial"),
        TranscriptListStatusMenuOption(id: "enhanced", label: "✨ Enhanced"),
        TranscriptListStatusMenuOption(id: "reviewed", label: "👀 Reviewed"),
        TranscriptListStatusMenuOption(id: "in_progress", label: "🔄 In Progress"),
        TranscriptListStatusMenuOption(id: "closed", label: "✅ Closed"),
        TranscriptListStatusMenuOption(id: "archived", label: "📦 Archived"),
        TranscriptListStatusMenuOption(id: "deleted", label: "🗑️ Deleted"),
    ]
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
