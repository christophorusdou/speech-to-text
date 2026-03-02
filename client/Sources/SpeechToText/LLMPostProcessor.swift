import Foundation

class LLMPostProcessor {
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "llmEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "llmEnabled") }
    }

    var endpoint: String {
        UserDefaults.standard.string(forKey: "llmEndpoint") ?? "http://localhost:11434"
    }

    var model: String {
        UserDefaults.standard.string(forKey: "llmModel") ?? "qwen3:8b"
    }

    func process(_ text: String) async throws -> String {
        guard isEnabled else { return text }

        let url = URL(string: "\(endpoint)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.1,
            "messages": [
                [
                    "role": "system",
                    "content": "Fix technical terms, names, and jargon. Only fix obvious errors, preserve everything else. Return only the corrected text."
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("LLM post-processing failed: HTTP \(statusCode)")
            return text
        }

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = result.choices.first?.message.content, !content.isEmpty else {
            return text
        }
        return content
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
}

private struct Choice: Decodable {
    let message: Message
}

private struct Message: Decodable {
    let content: String
}
