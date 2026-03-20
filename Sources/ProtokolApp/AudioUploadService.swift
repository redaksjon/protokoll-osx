import Foundation

/// Posts audio to the Protokoll server `/audio/upload` endpoint (same contract as `protokoll-vscode` `uploadService.ts`).
enum AudioUploadService {
    struct UploadResult {
        let success: Bool
        let uuid: String?
        let error: String?
    }

    private static let mimeByExtension: [String: String] = [
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4",
        "wav": "audio/wav",
        "webm": "audio/webm",
        "mp4": "video/mp4",
        "aac": "audio/aac",
        "ogg": "audio/ogg",
        "flac": "audio/flac",
        "aiff": "audio/aiff",
        "aif": "audio/aiff",
    ]

    static func upload(
        fileURL: URL,
        serverURL: String,
        apiKey: String?,
        title: String?,
        project: String?
    ) async -> UploadResult {
        let trimmedBase = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else {
            return UploadResult(success: false, uuid: nil, error: "No server URL configured")
        }

        var base = trimmedBase
        while base.hasSuffix("/") {
            base.removeLast()
        }

        guard let uploadURL = URL(string: base + "/audio/upload") else {
            return UploadResult(success: false, uuid: nil, error: "Invalid server URL")
        }

        let boundary = "----FormBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            return UploadResult(success: false, uuid: nil, error: "Failed to read file: \(error.localizedDescription)")
        }

        let body: Data
        do {
            body = try buildMultipartBody(
                fileData: fileData,
                filename: fileURL.lastPathComponent,
                boundary: boundary,
                title: title,
                project: project
            )
        } catch {
            return UploadResult(success: false, uuid: nil, error: error.localizedDescription)
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        request.timeoutInterval = 120

        if let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty,
           sameOrigin(uploadURL.absoluteString, profileURL: trimmedBase) {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return UploadResult(success: false, uuid: nil, error: "Invalid response")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return UploadResult(success: false, uuid: nil, error: "Failed to parse server response (HTTP \(http.statusCode))")
            }

            let successFlag = json["success"] as? Bool ?? false
            if (200..<300).contains(http.statusCode), successFlag {
                let uuid = json["uuid"] as? String
                return UploadResult(success: true, uuid: uuid, error: nil)
            }

            let err = (json["error"] as? String)
                ?? (json["details"] as? String)
                ?? "Server returned HTTP \(http.statusCode)"
            return UploadResult(success: false, uuid: nil, error: err)
        } catch {
            let msg = (error as NSError).code == NSURLErrorTimedOut
                ? "Upload timed out"
                : error.localizedDescription
            let friendly = msg.contains("Could not connect") || msg.contains("Connection refused")
                ? "Cannot connect to server at \(base). Is it reachable?"
                : "Upload failed: \(msg)"
            return UploadResult(success: false, uuid: nil, error: friendly)
        }
    }

    private static func sameOrigin(_ requestURL: String, profileURL: String) -> Bool {
        guard let r = URL(string: requestURL), let p = URL(string: profileURL),
              let rHost = r.host, let pHost = p.host else {
            return false
        }
        let rPort = r.port ?? (r.scheme?.lowercased() == "https" ? 443 : 80)
        let pPort = p.port ?? (p.scheme?.lowercased() == "https" ? 443 : 80)
        return r.scheme?.lowercased() == p.scheme?.lowercased() && rHost.lowercased() == pHost.lowercased() && rPort == pPort
    }

    private static func buildMultipartBody(
        fileData: Data,
        filename: String,
        boundary: String,
        title: String?,
        project: String?
    ) throws -> Data {
        let ext = (filename as NSString).pathExtension.lowercased()
        let mime = mimeByExtension[ext] ?? "application/octet-stream"

        var data = Data()

        let audioHeader =
            "--\(boundary)\r\n" +
            "Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n" +
            "Content-Type: \(mime)\r\n\r\n"
        guard let audioHeaderData = audioHeader.data(using: .utf8) else {
            throw NSError(domain: "AudioUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoding error"])
        }
        data.append(audioHeaderData)
        data.append(fileData)
        data.append(Data("\r\n".utf8))

        if let title, !title.isEmpty {
            let part =
                "--\(boundary)\r\n" +
                "Content-Disposition: form-data; name=\"title\"\r\n\r\n" +
                "\(title)\r\n"
            data.append(Data(part.utf8))
        }

        if let project, !project.isEmpty {
            let part =
                "--\(boundary)\r\n" +
                "Content-Disposition: form-data; name=\"project\"\r\n\r\n" +
                "\(project)\r\n"
            data.append(Data(part.utf8))
        }

        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }
}
