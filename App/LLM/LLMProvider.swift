import Foundation

// MARK: - Provider Configuration

/// Supported LLM providers with their API endpoints
public enum LLMProviderType: String, Codable, Sendable, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case custom = "custom"

    public var defaultEndpoint: String {
        switch self {
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .custom: return ""
        }
    }
}

/// Configuration for a single LLM provider
public struct LLMProviderConfig: Codable, Sendable {
    public var provider: LLMProviderType
    public var apiKey: String
    public var endpoint: String?  // nil = use provider default
    public var models: ProviderModels

    public init(
        provider: LLMProviderType,
        apiKey: String,
        endpoint: String? = nil,
        models: ProviderModels
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.models = models
    }

    public var resolvedEndpoint: String {
        endpoint ?? provider.defaultEndpoint
    }
}

/// Model assignments for a provider (fast, standard, powerful tiers)
public struct ProviderModels: Codable, Sendable {
    public var fast: String       // Cheap/fast for simple tasks
    public var standard: String   // General purpose
    public var powerful: String   // Best quality for complex tasks

    public init(fast: String, standard: String, powerful: String) {
        self.fast = fast
        self.standard = standard
        self.powerful = powerful
    }

    // Preset configurations
    public static let openAI = ProviderModels(
        fast: "gpt-4o-mini",
        standard: "gpt-4o",
        powerful: "gpt-4.5-preview"
    )

    public static let anthropic = ProviderModels(
        fast: "claude-3-5-haiku-latest",
        standard: "claude-sonnet-4-20250514",
        powerful: "claude-opus-4-20250514"
    )
}

// MARK: - Multi-Provider Registry

/// Central registry for all configured LLM providers
public struct LLMProviderRegistry: Codable, Sendable {
    public var providers: [String: LLMProviderConfig]  // keyed by user-defined name
    public var defaultProvider: String
    public var judgeProviders: [String]  // providers to use for dual-judge COA eval

    public init(
        providers: [String: LLMProviderConfig] = [:],
        defaultProvider: String = "openai",
        judgeProviders: [String] = []
    ) {
        self.providers = providers
        self.defaultProvider = defaultProvider
        self.judgeProviders = judgeProviders
    }

    /// Quick setup with OpenAI only
    public static func openAIOnly(apiKey: String) -> LLMProviderRegistry {
        LLMProviderRegistry(
            providers: [
                "openai": LLMProviderConfig(
                    provider: .openai,
                    apiKey: apiKey,
                    models: .openAI
                )
            ],
            defaultProvider: "openai",
            judgeProviders: ["openai"]
        )
    }

    /// Dual-provider setup (OpenAI + Anthropic)
    public static func dualProvider(
        openAIKey: String,
        anthropicKey: String
    ) -> LLMProviderRegistry {
        LLMProviderRegistry(
            providers: [
                "openai": LLMProviderConfig(
                    provider: .openai,
                    apiKey: openAIKey,
                    models: .openAI
                ),
                "anthropic": LLMProviderConfig(
                    provider: .anthropic,
                    apiKey: anthropicKey,
                    models: .anthropic
                )
            ],
            defaultProvider: "anthropic",
            judgeProviders: ["openai", "anthropic"]  // Both judge COAs
        )
    }
}

// MARK: - Provider-Aware Client

/// LLM client that can talk to multiple providers
public actor MultiProviderClient {
    private let registry: LLMProviderRegistry

    public init(registry: LLMProviderRegistry) {
        self.registry = registry
    }

    /// Complete a request using the specified provider and model tier
    public func complete(
        messages: [LLMMessage],
        providerName: String? = nil,
        tier: ModelTier = .standard
    ) async throws -> LLMResponse {
        let name = providerName ?? registry.defaultProvider
        guard let config = registry.providers[name] else {
            throw MultiProviderError.providerNotFound(name)
        }

        let model = tier.selectModel(from: config.models)

        switch config.provider {
        case .openai:
            return try await completeOpenAI(messages: messages, config: config, model: model)
        case .anthropic:
            return try await completeAnthropic(messages: messages, config: config, model: model)
        case .custom:
            return try await completeCustom(messages: messages, config: config, model: model)
        }
    }

    // MARK: - Provider-Specific Implementations

    private func completeOpenAI(
        messages: [LLMMessage],
        config: LLMProviderConfig,
        model: String
    ) async throws -> LLMResponse {
        let url = URL(string: config.resolvedEndpoint)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "messages": messages.map { [
                "role": $0.role.rawValue,
                "content": $0.content
            ]}
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MultiProviderError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }

        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = root["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return LLMResponse(text: content)
        }
        throw MultiProviderError.parseError
    }

    private func completeAnthropic(
        messages: [LLMMessage],
        config: LLMProviderConfig,
        model: String
    ) async throws -> LLMResponse {
        let url = URL(string: config.resolvedEndpoint)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Anthropic format: separate system from messages
        let systemMsg = messages.first { $0.role == .system }?.content ?? ""
        let userMessages = messages.filter { $0.role != .system }

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemMsg,
            "messages": userMessages.map { [
                "role": $0.role == .assistant ? "assistant" : "user",
                "content": $0.content
            ]}
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MultiProviderError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }

        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = root["content"] as? [[String: Any]],
           let first = content.first,
           let text = first["text"] as? String {
            return LLMResponse(text: text)
        }
        throw MultiProviderError.parseError
    }

    private func completeCustom(
        messages: [LLMMessage],
        config: LLMProviderConfig,
        model: String
    ) async throws -> LLMResponse {
        // Custom endpoint assumes OpenAI-compatible API format
        return try await completeOpenAI(messages: messages, config: config, model: model)
    }
}

// MARK: - Model Tier

/// Model quality/cost tier for task-based routing
public enum ModelTier: String, Codable, Sendable {
    case fast      // Cheap, low-latency (parsing, simple decisions)
    case standard  // General purpose (most specialist work)
    case powerful  // Best quality (COA generation, complex reasoning)

    public func selectModel(from models: ProviderModels) -> String {
        switch self {
        case .fast: return models.fast
        case .standard: return models.standard
        case .powerful: return models.powerful
        }
    }
}

// MARK: - Errors

public enum MultiProviderError: Error {
    case providerNotFound(String)
    case apiError(String)
    case parseError
}
