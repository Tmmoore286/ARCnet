import Foundation

// MARK: - LLM Router
// Routes LLM requests to appropriate providers and model tiers based on pipeline stage.

/// Pipeline stages that require LLM calls
public enum PipelineStage: String, Codable, Sendable, CaseIterable {
    // Stage agents
    case scribe           // Transcribes and structures input
    case coordinator      // Routes to specialists
    case integrator       // Synthesizes specialist outputs
    case evaluator        // Scores and ranks COAs
    case tasking          // Generates execution tasks

    // Specialist work
    case specialist       // Domain experts (G1-G9 equivalent)

    // COA generation
    case coaGenerator     // Generates course of action options
    case coaJudge         // Evaluates COAs (used for dual-judge)

    // Utility
    case embedding        // Vector embeddings for similarity
    case parsing          // Simple parsing/extraction
}

/// Routing configuration per stage
public struct StageRoutingConfig: Codable, Sendable {
    public var tier: ModelTier
    public var provider: String?  // nil = use default provider
    public var maxTokens: Int

    public init(tier: ModelTier, provider: String? = nil, maxTokens: Int = 4096) {
        self.tier = tier
        self.provider = provider
        self.maxTokens = maxTokens
    }
}

/// Central LLM router that directs requests based on task requirements
public actor LLMRouter {
    private let registry: LLMProviderRegistry
    private let client: MultiProviderClient
    private var stageConfigs: [PipelineStage: StageRoutingConfig]

    public init(registry: LLMProviderRegistry) {
        self.registry = registry
        self.client = MultiProviderClient(registry: registry)
        self.stageConfigs = Self.defaultStageConfigs()
    }

    /// Default routing configuration optimized for cost/quality balance
    private static func defaultStageConfigs() -> [PipelineStage: StageRoutingConfig] {
        [
            // Fast tier: simple, high-volume tasks
            .scribe: StageRoutingConfig(tier: .fast, maxTokens: 1024),
            .coordinator: StageRoutingConfig(tier: .fast, maxTokens: 512),
            .parsing: StageRoutingConfig(tier: .fast, maxTokens: 256),

            // Standard tier: balanced quality/cost
            .specialist: StageRoutingConfig(tier: .standard, maxTokens: 2048),
            .integrator: StageRoutingConfig(tier: .standard, maxTokens: 4096),
            .tasking: StageRoutingConfig(tier: .standard, maxTokens: 2048),

            // Powerful tier: complex reasoning tasks
            .coaGenerator: StageRoutingConfig(tier: .powerful, maxTokens: 8192),
            .evaluator: StageRoutingConfig(tier: .powerful, maxTokens: 4096),
            .coaJudge: StageRoutingConfig(tier: .powerful, maxTokens: 4096),

            // Embedding uses its own endpoint (not chat completions)
            .embedding: StageRoutingConfig(tier: .fast, maxTokens: 0)
        ]
    }

    /// Override routing config for a specific stage
    public func setConfig(for stage: PipelineStage, config: StageRoutingConfig) {
        stageConfigs[stage] = config
    }

    /// Route a completion request to the appropriate provider and model
    public func complete(
        stage: PipelineStage,
        messages: [LLMMessage],
        providerOverride: String? = nil
    ) async throws -> LLMResponse {
        let config = stageConfigs[stage] ?? StageRoutingConfig(tier: .standard)
        let provider = providerOverride ?? config.provider

        return try await client.complete(
            messages: messages,
            providerName: provider,
            tier: config.tier
        )
    }

    /// Get the model tier for a given stage (useful for logging/metrics)
    public func tierFor(stage: PipelineStage) -> ModelTier {
        stageConfigs[stage]?.tier ?? .standard
    }

    /// Get the provider name for a given stage
    public func providerFor(stage: PipelineStage) -> String {
        stageConfigs[stage]?.provider ?? registry.defaultProvider
    }
}

// MARK: - Specialist Router Extension

extension LLMRouter {
    /// Route a specialist agent's request, potentially using complexity-based tier escalation
    public func completeSpecialist(
        messages: [LLMMessage],
        complexity: TaskComplexity = .standard,
        shop: String? = nil
    ) async throws -> LLMResponse {
        // Escalate to powerful tier for high-complexity tasks
        let tier: ModelTier = complexity == .high ? .powerful : .standard

        return try await client.complete(
            messages: messages,
            providerName: nil,  // Use default
            tier: tier
        )
    }
}

/// Task complexity level for adaptive tier selection
public enum TaskComplexity: String, Codable, Sendable {
    case low       // Simple lookups, status checks
    case standard  // Normal specialist reasoning
    case high      // Complex multi-factor analysis
}

// MARK: - Metrics Collection

extension LLMRouter {
    /// Metrics for a single LLM call
    public struct CallMetrics: Codable, Sendable {
        public var stage: PipelineStage
        public var provider: String
        public var model: String
        public var tier: ModelTier
        public var inputTokens: Int
        public var outputTokens: Int
        public var latencyMs: Int

        public init(
            stage: PipelineStage,
            provider: String,
            model: String,
            tier: ModelTier,
            inputTokens: Int,
            outputTokens: Int,
            latencyMs: Int
        ) {
            self.stage = stage
            self.provider = provider
            self.model = model
            self.tier = tier
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.latencyMs = latencyMs
        }
    }
}
