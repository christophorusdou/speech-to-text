import Foundation

class TranscriptionService {
    static var endpoint: String {
        UserDefaults.standard.string(forKey: "endpoint") ?? "http://localhost:8000"
    }

    var model: String = UserDefaults.standard.string(forKey: "model")
        ?? "deepdml/faster-whisper-large-v3-turbo-ct2"
    var language: String = UserDefaults.standard.string(forKey: "language") ?? "en"

    func transcribe(fileURL: URL) async throws -> String {
        let url = URL(string: "\(Self.endpoint)/v1/audio/transcriptions")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let audioData = try Data(contentsOf: fileURL)
        var body = Data()

        // model field
        body.appendMultipart(boundary: boundary, name: "model", value: model)

        // language hint — improves accuracy vs auto-detect
        body.appendMultipart(boundary: boundary, name: "language", value: language)

        // audio file — use fixed filename so server detects WAV by extension
        body.appendMultipart(boundary: boundary, name: "file",
                             filename: "recording.wav",
                             mimeType: "audio/wav", data: audioData)

        // close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TranscriptionError.serverError(statusCode: statusCode, body: body)
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    func fetchModels() async -> [String] {
        guard let url = URL(string: "\(Self.endpoint)/v1/models") else { return [model] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let models = response.data.map { $0.id }
            return models.isEmpty ? [model] : models
        } catch {
            return [model]
        }
    }
}

private struct ModelsResponse: Decodable {
    let data: [ModelEntry]
}

private struct ModelEntry: Decodable {
    let id: String
}

enum TranscriptionError: LocalizedError {
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .serverError(let code, let body):
            return "Server error \(code): \(body)"
        }
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
