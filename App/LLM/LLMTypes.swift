import Foundation

public struct LLMMessage: Sendable, Codable {
    public enum Role: String, Codable { case system, user, assistant }
    public var role: Role
    public var content: String
    public init(role: Role, content: String) { self.role = role; self.content = content }
}

public struct LLMConfig: Sendable, Codable {
    public var model: String
    public var apiKey: String?
    public init(model: String = "gpt-5", apiKey: String? = nil) { self.model = model; self.apiKey = apiKey }
}

public struct LLMResponse: Sendable, Codable {
    public var text: String
}

public protocol LLMClient {
    func complete(messages: [LLMMessage], config: LLMConfig) async throws -> LLMResponse
}

