import Foundation

public enum LLMClientError: Error {
    case missingApiKey
    case badResponse
}

public struct OpenAIClient: LLMClient {
    public init() {}

    public func complete(messages: [LLMMessage], config: LLMConfig) async throws -> LLMResponse {
        guard let apiKey = config.apiKey, !apiKey.isEmpty else { throw LLMClientError.missingApiKey }

        // Minimal Chat Completions request for text output
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": config.model,
            "messages": messages.map { [
                "role": $0.role.rawValue,
                "content": $0.content
            ]}
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LLMClientError.badResponse
        }

        // Parse assistant message text
        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = root["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return LLMResponse(text: content)
        }
        throw LLMClientError.badResponse
    }
}

