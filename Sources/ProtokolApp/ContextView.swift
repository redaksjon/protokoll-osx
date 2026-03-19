import SwiftUI
import OSLog
import ProtokolLib

struct ContextView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: ContextCategory = .people
    @State private var entities: [MCPEntity] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var selectedEntity: MCPEntity?

    private let logger = Logger(subsystem: "com.protokoll.app", category: "context")

    enum ContextCategory: String, CaseIterable {
        case people = "People"
        case projects = "Projects"
        case companies = "Companies"
        case terms = "Terms"

        var listToolName: String {
            switch self {
            case .people: return "protokoll_list_people"
            case .projects: return "protokoll_list_projects"
            case .companies: return "protokoll_list_companies"
            case .terms: return "protokoll_list_terms"
            }
        }

        var listResponseKey: String {
            switch self {
            case .people: return "people"
            case .projects: return "projects"
            case .companies: return "companies"
            case .terms: return "terms"
            }
        }

        var entityType: String {
            switch self {
            case .people: return "person"
            case .projects: return "project"
            case .companies: return "company"
            case .terms: return "term"
            }
        }
    }

    var filteredEntities: [MCPEntity] {
        guard !searchText.isEmpty else { return entities }
        return entities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Context Entities")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { Task { await loadEntities() } }) {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding()

                Picker("Category", selection: $selectedCategory) {
                    ForEach(ContextCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search \(selectedCategory.rawValue.lowercased())…", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding()

                Divider()

                if isLoading && entities.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading \(selectedCategory.rawValue.lowercased())…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") { Task { await loadEntities() } }
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEntities.isEmpty {
                    Text("No \(selectedCategory.rawValue.lowercased()) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredEntities, selection: $selectedEntity) { entity in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entity.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let subtitle = entity.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .tag(entity)
                    }
                }
            }
            .frame(minWidth: 260)
        } detail: {
            if let entity = selectedEntity {
                EntityDetailView(entity: entity, category: selectedCategory)
                    .id("\(entity.id)-\(selectedCategory.rawValue)")
            } else {
                Text("Select an entity")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadEntities()
        }
        .onChange(of: selectedCategory) { _, _ in
            entities.removeAll()
            selectedEntity = nil
            searchText = ""
            Task { await loadEntities() }
        }
        .onChange(of: appState.mcpInitialized) { _, initialized in
            if initialized && entities.isEmpty {
                Task { await loadEntities() }
            }
        }
        .onChange(of: appState.serverSwitchGeneration) { _, _ in
            entities.removeAll()
            selectedEntity = nil
            error = nil
            if appState.mcpInitialized {
                Task { await loadEntities() }
            }
        }
    }

    private func loadEntities() async {
        guard let client = appState.mcpClient else {
            await MainActor.run { error = "MCP not connected" }
            return
        }
        await MainActor.run {
            isLoading = true
            error = nil
        }
        do {
            let response = try await client.callTool(
                name: selectedCategory.listToolName,
                arguments: ["limit": 200]
            )
            guard let textContent = response.content.first(where: { $0.type == "text" }),
                  let text = textContent.text,
                  let data = text.data(using: .utf8) else {
                throw MCPClientError.noResult
            }

            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let key = selectedCategory.listResponseKey
            let items = parsed?[key] as? [[String: Any]] ?? []

            let mapped: [MCPEntity] = items.compactMap { item in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String ?? item["term"] as? String else {
                    return nil
                }
                let subtitle: String?
                if let role = item["role"] as? String, let company = item["company"] as? String {
                    subtitle = "\(role) at \(company)"
                } else if let context = item["context"] as? String, !context.isEmpty {
                    subtitle = String(context.prefix(80))
                } else {
                    subtitle = nil
                }
                let uri = "protokoll://entity/\(selectedCategory.entityType)/\(id)"
                return MCPEntity(id: id, name: name, uri: uri, subtitle: subtitle)
            }

            await MainActor.run {
                entities = mapped
                isLoading = false
            }
        } catch {
            logger.error("Failed to load entities: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct MCPEntity: Identifiable, Hashable {
    let id: String
    let name: String
    let uri: String
    let subtitle: String?
}

struct EntityDetailView: View {
    @EnvironmentObject var appState: AppState
    let entity: MCPEntity
    let category: ContextView.ContextCategory

    @State private var detailJSON: String = ""
    @State private var isLoading = true
    @State private var error: String?

    private let logger = Logger(subsystem: "com.protokoll.app", category: "entity-detail")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entity.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(category.rawValue) — \(entity.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(detailJSON, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .controlSize(.small)
                    .disabled(detailJSON.isEmpty)
                }

                Divider()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading entity details…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if let error {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadDetail() } }
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    Text(detailJSON)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                        .lineSpacing(4)
                }
            }
            .padding()
        }
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        guard let client = appState.mcpClient else {
            await MainActor.run { error = "MCP not connected"; isLoading = false }
            return
        }
        await MainActor.run { isLoading = true; error = nil }
        do {
            let content = try await client.readResource(uri: entity.uri)
            await MainActor.run {
                detailJSON = content.text ?? "No content"
                isLoading = false
            }
        } catch {
            logger.error("Failed to load entity detail: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}
