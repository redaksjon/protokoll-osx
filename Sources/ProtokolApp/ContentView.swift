import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            DetailView()
        }
        .task {
            // Initialize MCP after UI is ready
            await appState.initializeMCP()
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(selection: $appState.selectedTab) {
            ForEach(AppState.MainTab.allCases, id: \.self) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: iconForTab(tab))
                }
            }
            Section("Servers") {
                MCPServersStatusSection()
            }
        }
        .navigationTitle("Protokoll")
        .frame(minWidth: 200)
    }
    
    func iconForTab(_ tab: AppState.MainTab) -> String {
        switch tab {
        case .transcribe: return "waveform.circle.fill"
        case .transcripts: return "doc.text.fill"
        case .context: return "brain.head.profile"
        case .activity: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct MCPServersStatusSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.settings.mcpServers.isEmpty {
                Text("No MCP servers configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.settings.mcpServers) { server in
                    MCPServerStatusRow(server: server)
                }
            }
            if let error = appState.mcpError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MCPServerStatusRow: View {
    @EnvironmentObject var appState: AppState
    let server: MCPServerProfile

    private var status: MCPServerConnectionStatus {
        appState.status(for: server.id)
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .failed: return .red
        case .disconnected: return .secondary
        }
    }

    private var statusLabel: String {
        switch status {
        case .connected: return "Connected"
        case .connecting: return "Connecting…"
        case .failed: return "Failed"
        case .disconnected: return "Disconnected"
        }
    }

    private var isActive: Bool {
        appState.settings.activeMCPServerID == server.id
    }

    private var isConnected: Bool {
        status == .connected
    }

    private var isConnecting: Bool {
        status == .connecting
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isConnecting {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.subheadline)
                        .fontWeight(isActive ? .semibold : .regular)
                    if isActive {
                        Text("active")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(statusColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(statusColor)
                    }
                }
                Text(server.displayAddress)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Connect") {
                Task {
                    await appState.connectToServer(server.id)
                }
            }
            .disabled(isConnected || isConnecting)

            Button("Disconnect") {
                Task {
                    await appState.disconnectActiveServer()
                }
            }
            .disabled(!isActive || !isConnected)

            Divider()

            Button("Set as Active") {
                appState.settings.activeMCPServerID = server.id
                appState.persistSettings()
            }
            .disabled(isActive)

            Divider()

            Button("Edit in Settings…") {
                appState.pendingEditServerID = server.id
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .help("\(server.name) — \(server.displayAddress) (\(statusLabel))")
    }
}

struct DetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.selectedTab {
            case .transcribe:
                TranscribeView()
            case .transcripts:
                TranscriptsView()
            case .context:
                ContextView()
            case .activity:
                ActivityView()
            }
        }
    }
}
