import Foundation

class ProtokolService {
    static let shared = ProtokolService()

    private init() {}

    func processAudioFile(_ file: ProcessingFile, appState: AppState) {
        guard appState.processingFiles.contains(where: { $0.id == file.id }) else {
            return
        }

        if let server = appState.activeServer,
           server.connectionType == .remoteHTTP,
           !server.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await processAudioFileRemote(file: file, appState: appState, server: server)
            }
            return
        }

        processAudioFileLocalCLI(file: file, appState: appState)
    }

    private func processAudioFileRemote(file: ProcessingFile, appState: AppState, server: MCPServerProfile) async {
        await MainActor.run {
            guard let i = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
            appState.processingFiles[i].status = .transcribing
            appState.processingFiles[i].output = "Uploading to server..."
        }

        let token = AppState.resolveToken(for: server)
        let titleHint = file.url.deletingPathExtension().lastPathComponent

        let didAccess = file.url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                file.url.stopAccessingSecurityScopedResource()
            }
        }

        let result = await AudioUploadService.upload(
            fileURL: file.url,
            serverURL: server.serverURL,
            apiKey: token,
            title: titleHint,
            project: nil
        )

        await MainActor.run {
            guard let i = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
            if result.success {
                appState.processingFiles[i].status = .completed
                appState.processingFiles[i].output = ""
                appState.processingFiles[i].error = nil
            } else {
                appState.processingFiles[i].status = .failed
                appState.processingFiles[i].error = result.error ?? "Upload failed"
            }
        }
    }

    private func processAudioFileLocalCLI(file: ProcessingFile, appState: AppState) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Update status to transcribing
            DispatchQueue.main.async {
                guard let idx = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
                appState.processingFiles[idx].status = .transcribing
            }

            // Build command
            let settings = appState.settings
            var arguments = [
                "--input-directory", file.url.deletingLastPathComponent().path,
                "--output-directory", settings.outputDirectory,
                "--model", settings.model,
                "--transcription-model", settings.transcriptionModel,
            ]

            if !settings.interactive {
                arguments.append("--batch")
            }

            if settings.selfReflection {
                arguments.append("--self-reflection")
            }

            if settings.verbose {
                arguments.append("--verbose")
            }

            // Execute protokoll
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", "\(settings.protokollPath) \(arguments.joined(separator: " "))"]

            // Set environment
            var environment = ProcessInfo.processInfo.environment
            if !settings.openaiApiKey.isEmpty {
                environment["OPENAI_API_KEY"] = settings.openaiApiKey
            }
            task.environment = environment

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()

                // Update status to enhancing
                DispatchQueue.main.async {
                    guard let idx = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
                    appState.processingFiles[idx].status = .enhancing
                }

                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    // Success
                    DispatchQueue.main.async {
                        guard let idx = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
                        appState.processingFiles[idx].status = .completed
                    }

                    // Try to load the generated transcript
                    self.loadGeneratedTranscript(for: file, appState: appState)
                } else {
                    // Failed
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"

                    DispatchQueue.main.async {
                        guard let idx = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
                        appState.processingFiles[idx].status = .failed
                        appState.processingFiles[idx].error = output
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let idx = appState.processingFiles.firstIndex(where: { $0.id == file.id }) else { return }
                    appState.processingFiles[idx].status = .failed
                    appState.processingFiles[idx].error = error.localizedDescription
                }
            }
        }
    }

    func loadGeneratedTranscript(for file: ProcessingFile, appState: AppState) {
        // Try to find the generated transcript file
        // This is a simplified version - you'd need to parse protokoll's output
        // to get the actual output path

        let outputDir = appState.settings.outputDirectory
        let fm = FileManager.default

        do {
            _ = try fm.contentsOfDirectory(atPath: outputDir)

            // For demo purposes, create a sample transcript
            let transcript = Transcript(
                title: file.url.deletingPathExtension().lastPathComponent,
                date: Date(),
                filePath: "\(outputDir)/\(file.url.deletingPathExtension().lastPathComponent).pkl",
                project: "Default",
                duration: "5m 30s",
                confidence: 0.92,
                content: "Transcript content would be loaded from the generated file..."
            )

            DispatchQueue.main.async {
                appState.transcripts.insert(transcript, at: 0)
            }
        } catch {
            print("Error loading transcript: \(error)")
        }
    }

    func loadContext(appState: AppState) {
        DispatchQueue.global(qos: .userInitiated).async {
            let contextDir = appState.settings.contextDirectory
            let fm = FileManager.default

            // Load people
            let peopleDir = "\(contextDir)/people"
            if let peopleFiles = try? fm.contentsOfDirectory(atPath: peopleDir) {
                let people = peopleFiles
                    .filter { $0.hasSuffix(".yaml") }
                    .compactMap { self.loadPerson(from: "\(peopleDir)/\($0)") }

                DispatchQueue.main.async {
                    appState.contextData.people = people
                }
            }

            // Load projects
            let projectsDir = "\(contextDir)/projects"
            if let projectFiles = try? fm.contentsOfDirectory(atPath: projectsDir) {
                let projects = projectFiles
                    .filter { $0.hasSuffix(".yaml") }
                    .compactMap { self.loadProject(from: "\(projectsDir)/\($0)") }

                DispatchQueue.main.async {
                    appState.contextData.projects = projects
                }
            }

            // Similar for companies and terms...
        }
    }

    private func loadPerson(from path: String) -> Person? {
        // Simplified YAML parsing - in real implementation, use proper YAML parser
        guard let content = try? String(contentsOfFile: path) else { return nil }

        // This is a very basic parser - you'd want to use a proper YAML library
        let lines = content.components(separatedBy: .newlines)
        var person = Person(id: "", name: "", soundsLike: [])

        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "id": person.id = value
            case "name": person.name = value
            case "firstName": person.firstName = value
            case "lastName": person.lastName = value
            case "company": person.company = value
            case "role": person.role = value
            case "context": person.context = value
            default: break
            }
        }

        return person.id.isEmpty ? nil : person
    }

    private func loadProject(from path: String) -> Project? {
        // Similar simplified parsing for projects
        guard let content = try? String(contentsOfFile: path) else { return nil }

        var project = Project(
            id: "", name: "", type: "project", contextType: "work",
            destination: "", structure: "month",
            explicitPhrases: [], topics: [], soundsLike: [], active: true
        )

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "id": project.id = value
            case "name": project.name = value
            case "type": project.type = value
            default: break
            }
        }

        return project.id.isEmpty ? nil : project
    }
}
