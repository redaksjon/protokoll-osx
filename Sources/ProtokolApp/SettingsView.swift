import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var settings: ProtokolSettings
    @State private var showSavedConfirmation = false
    
    init() {
        _settings = State(initialValue: ProtokolSettings())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralSettingsView(settings: $settings)
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                
                PathsSettingsView(settings: $settings)
                    .tabItem {
                        Label("Paths", systemImage: "folder")
                    }
                
                ModelsSettingsView(settings: $settings)
                    .tabItem {
                        Label("Models", systemImage: "cpu")
                    }
                
                AdvancedSettingsView(settings: $settings, appState: appState)
                    .tabItem {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            HStack {
                if showSavedConfirmation {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Settings saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                Button("Save Settings") {
                    let mcpURLChanged = appState.settings.mcpServerURL != settings.mcpServerURL
                    appState.settings = settings
                    appState.persistSettings()
                    withAnimation {
                        showSavedConfirmation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showSavedConfirmation = false
                        }
                    }
                    // Reconnect MCP if the server URL changed
                    if mcpURLChanged {
                        Task {
                            await appState.shutdownMCP()
                            await appState.initializeMCP()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 550, height: 440)
        .onAppear {
            settings = appState.settings
        }
    }
}

struct GeneralSettingsView: View {
    @Binding var settings: ProtokolSettings
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("API Configuration") {
                SecureField("OpenAI API Key", text: $settings.openaiApiKey)
                    .help("Your OpenAI API key for transcription")
                
                Text("Get your API key at platform.openai.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Processing Options") {
                Toggle("Interactive Mode", isOn: $settings.interactive)
                    .help("Ask for clarification during processing")
                
                Toggle("Self Reflection", isOn: $settings.selfReflection)
                    .help("Generate quality reports after processing")
                
                Toggle("Verbose Logging", isOn: $settings.verbose)
                    .help("Show detailed processing information")
            }
        }
        .padding()
    }
}

struct PathsSettingsView: View {
    @Binding var settings: ProtokolSettings
    
    var body: some View {
        Form {
            Section("Directories") {
                HStack {
                    TextField("Input Directory", text: $settings.inputDirectory)
                    Button("Choose...") {
                        selectDirectory(for: \.inputDirectory)
                    }
                }
                
                HStack {
                    TextField("Output Directory", text: $settings.outputDirectory)
                    Button("Choose...") {
                        selectDirectory(for: \.outputDirectory)
                    }
                }
                
                HStack {
                    TextField("Context Directory", text: $settings.contextDirectory)
                    Button("Choose...") {
                        selectDirectory(for: \.contextDirectory)
                    }
                }
            }
            
            Section("Protokoll CLI") {
                TextField("Protokoll Path", text: $settings.protokollPath)
                    .help("Path to the protokoll command")
                
                Button("Verify Installation") {
                    verifyProtokolInstallation()
                }
            }
        }
        .padding()
    }
    
    func selectDirectory(for keyPath: WritableKeyPath<ProtokolSettings, String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            settings[keyPath: keyPath] = url.path
        }
    }
    
    func verifyProtokolInstallation() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "\(settings.protokollPath) --version"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                showAlert(title: "Success", message: "Protokoll is installed correctly")
            } else {
                showAlert(title: "Error", message: "Protokoll not found at specified path")
            }
        } catch {
            showAlert(title: "Error", message: "Failed to verify installation: \(error.localizedDescription)")
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

struct ModelsSettingsView: View {
    @Binding var settings: ProtokolSettings
    
    let reasoningModels = [
        "gpt-5.2", "gpt-5.1", "gpt-5", "gpt-4o", "gpt-4o-mini",
        "claude-3-5-sonnet", "claude-3-opus"
    ]
    
    let transcriptionModels = [
        "whisper-1", "gpt-4o-transcribe"
    ]
    
    var body: some View {
        Form {
            Section("AI Models") {
                Picker("Reasoning Model", selection: $settings.model) {
                    ForEach(reasoningModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .help("Model used for transcript enhancement and routing")
                
                Picker("Transcription Model", selection: $settings.transcriptionModel) {
                    ForEach(transcriptionModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .help("Model used for audio transcription")
            }
            
            Section("Model Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("gpt-5.2: High reasoning, best quality (default)")
                    Text("gpt-4o: Fast and capable")
                    Text("claude-3-5-sonnet: Excellent for long context")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @Binding var settings: ProtokolSettings
    @ObservedObject var appState: AppState
    @State private var isReconnecting = false
    @State private var reconnectMessage: String?
    @State private var reconnectSuccess: Bool?
    
    var body: some View {
        Form {
            Section("MCP Server") {
                TextField("MCP Server URL", text: $settings.mcpServerURL)
                    .help("HTTP URL of the MCP server (e.g. http://127.0.0.1:3001). Clear to use stdio subprocess mode.")
                Text("Connects to the Protokoll MCP server via HTTP. This should match the server URL used by the VSCode extension. Clear the field to spawn protokoll-mcp as a subprocess instead.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Reconnect MCP") {
                    reconnectTapped()
                }
                .disabled(isReconnecting)
                .help("Apply the current Remote MCP URL and reconnect.")
                
                if isReconnecting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Reconnecting…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let message = reconnectMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(reconnectSuccess == true ? .green : .red)
                }
            }
            
            Section("MCP debug log") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Request/response log for debugging. Also in Console.app (filter: com.protokoll.mcp).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") {
                            appState.clearMCPLog()
                        }
                        .buttonStyle(.borderless)
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(appState.mcpDebugLog.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(6)
                        }
                        .frame(height: 140)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onChange(of: appState.mcpDebugLog.count) { _, _ in
                            if let last = appState.mcpDebugLog.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func reconnectTapped() {
        reconnectMessage = nil
        reconnectSuccess = nil
        isReconnecting = true
        appState.settings = settings
        appState.persistSettings()
        Task {
            await appState.shutdownMCP()
            await appState.initializeMCP()
            await MainActor.run {
                isReconnecting = false
                reconnectSuccess = appState.mcpInitialized
                reconnectMessage = appState.mcpInitialized
                    ? "Connected"
                    : (appState.mcpError ?? "Connection failed")
            }
        }
    }
}
