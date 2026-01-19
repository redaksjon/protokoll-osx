import SwiftUI
import UniformTypeIdentifiers

struct TranscribeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDragging = false
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                
                Text("Audio Transcription")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Transform voice memos into perfectly organized notes")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Drop zone
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isDragging ? Color.blue : Color.gray.opacity(0.3),
                            style: StrokeStyle(lineWidth: 3, dash: [10])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isDragging ? Color.blue.opacity(0.1) : Color.clear)
                        )
                        .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        Image(systemName: isDragging ? "arrow.down.circle.fill" : "mic.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(isDragging ? .blue : .gray)
                        
                        Text(isDragging ? "Drop files here" : "Drag audio files here")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("or")
                            .foregroundColor(.secondary)
                        
                        Button("Choose Files") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 40)
                .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                    return true
                }
                
                Text("Supported formats: .m4a, .mp3, .wav, .aiff, .flac")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Processing queue
            if !appState.processingFiles.isEmpty {
                ProcessingQueueView()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                UTType.audio,
                UTType(filenameExtension: "m4a")!
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                processFiles(urls)
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        processFiles([url])
                    }
                }
            }
        }
    }
    
    func processFiles(_ urls: [URL]) {
        for url in urls {
            let file = ProcessingFile(url: url)
            appState.processingFiles.append(file)
            ProtokolService.shared.processAudioFile(file, appState: appState)
        }
    }
}

struct ProcessingQueueView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Processing Queue")
                    .font(.headline)
                Spacer()
                Text("\(appState.processingFiles.filter { $0.status != .completed && $0.status != .failed }.count) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.processingFiles) { file in
                        ProcessingFileRow(file: file)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ProcessingFileRow: View {
    let file: ProcessingFile
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.url.lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if file.status != .completed && file.status != .failed {
                ProgressView()
                    .scaleEffect(0.7)
            } else if file.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if file.status == .failed {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
    
    var statusIcon: String {
        switch file.status {
        case .pending: return "clock"
        case .transcribing: return "waveform"
        case .enhancing: return "sparkles"
        case .routing: return "arrow.triangle.branch"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
    
    var statusColor: Color {
        switch file.status {
        case .pending: return .gray
        case .transcribing, .enhancing, .routing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    var statusText: String {
        switch file.status {
        case .pending: return "Waiting..."
        case .transcribing: return "Transcribing audio..."
        case .enhancing: return "Enhancing with AI..."
        case .routing: return "Routing to destination..."
        case .completed: return "Completed"
        case .failed: return file.error ?? "Failed"
        }
    }
}
