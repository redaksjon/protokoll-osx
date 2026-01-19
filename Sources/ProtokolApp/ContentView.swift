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
