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
            Section {
                MCPConnectionStatusView()
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

struct MCPConnectionStatusView: View {
    @EnvironmentObject var appState: AppState
    @State private var isReconnecting = false
    
    private var statusColor: Color {
        appState.mcpInitialized ? Color.green : Color.red
    }
    
    private var statusLabel: String {
        if isReconnecting { return "Reconnecting..." }
        return appState.mcpInitialized ? "MCP connected" : "MCP disconnected"
    }
    
    private var statusDetail: String? {
        if isReconnecting { return nil }
        if appState.mcpInitialized {
            let url = appState.settings.mcpServerURL
            return url.isEmpty ? "stdio" : url
        }
        return appState.mcpError ?? "Not connected"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if isReconnecting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if let detail = statusDetail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            
            if !appState.mcpInitialized && !isReconnecting {
                Button {
                    Task {
                        isReconnecting = true
                        await appState.shutdownMCP()
                        await appState.initializeMCP()
                        isReconnecting = false
                    }
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .help(statusDetail ?? "Connected to MCP server")
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
