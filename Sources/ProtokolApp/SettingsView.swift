import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var settings: ProtokolSettings
    
    init() {
        _settings = State(initialValue: ProtokolSettings())
    }
    
    var body: some View {
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
            
            AdvancedSettingsView(settings: $settings)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 550, height: 400)
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
            
            HStack {
                Spacer()
                Button("Save Settings") {
                    appState.settings = settings
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    func saveSettings() {
        // Save to UserDefaults or file
        print("Settings saved")
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
    
    var body: some View {
        Form {
            Section("Advanced Options") {
                Text("Coming soon...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
