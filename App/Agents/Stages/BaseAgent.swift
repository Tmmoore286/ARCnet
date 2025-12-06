import Foundation
import ARCnetDomain
import ARCnetLLM

// MARK: - Base Agent Implementation
// Provides common functionality for all agents.

public class BaseAgent: Agent, @unchecked Sendable {
    public let id: String
    public let name: String
    public let mosCode: String?
    public let shop: String?
    public let mcppPhase: String

    internal let llmClient: LLMClient
    internal let config: LLMConfig

    public init(
        id: String,
        name: String,
        mosCode: String? = nil,
        shop: String? = nil,
        mcppPhase: String,
        llmClient: LLMClient,
        config: LLMConfig = LLMConfig()
    ) {
        self.id = id
        self.name = name
        self.mosCode = mosCode
        self.shop = shop
        self.mcppPhase = mcppPhase
        self.llmClient = llmClient
        self.config = config
    }

    public func run(
        input: AgentInput,
        context: MissionContext,
        doctrine: [DoctrineSnippet]
    ) async throws -> AgentOutput {
        // Build prompt
        let systemPrompt = buildSystemPrompt(doctrine: doctrine)
        let userPrompt = buildUserPrompt(input: input, context: context)

        // Call LLM
        let messages = [
            LLMMessage(role: .system, content: systemPrompt),
            LLMMessage(role: .user, content: userPrompt)
        ]

        let response = try await llmClient.complete(messages: messages, config: config)

        // Parse and return output
        return parseResponse(response.text, input: input)
    }

    // MARK: - Override Points

    /// Build system prompt for this agent type
    internal func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        var prompt = """
        You are \(name), an AI assistant specialized in \(mcppPhase) for military decision support.

        Your role is to provide clear, actionable analysis based on the mission context and available data.

        Guidelines:
        - Be concise and direct
        - Cite evidence when making claims
        - Express confidence levels (high/medium/low)
        - Identify conflicts or issues
        - Provide specific recommendations
        """

        if !doctrine.isEmpty {
            prompt += "\n\nRelevant Doctrine:\n"
            for doc in doctrine.prefix(3) {  // Limit to 3 docs to manage context
                prompt += "[\(doc.docId)] \(doc.title): \(doc.content.prefix(500))\n"
            }
        }

        return prompt
    }

    /// Build user prompt with mission context
    internal func buildUserPrompt(input: AgentInput, context: MissionContext) -> String {
        var prompt = """
        Mission Statement: \(input.missionStatement)

        Commander's Intent: \(context.intent)
        End State: \(context.endState)
        """

        if !context.constraints.isEmpty {
            prompt += "\n\nConstraints:\n"
            for constraint in context.constraints {
                prompt += "- \(constraint)\n"
            }
        }

        if !context.acceptanceCriteria.isEmpty {
            prompt += "\n\nAcceptance Criteria:\n"
            for criteria in context.acceptanceCriteria {
                prompt += "- \(criteria)\n"
            }
        }

        if !input.priorCheckpoints.isEmpty {
            prompt += "\n\nPrior Analysis:\n"
            for checkpoint in input.priorCheckpoints.suffix(3) {
                prompt += "[\(checkpoint.stage)] \(checkpoint.summary)\n"
            }
        }

        if let snapshots = input.dataSnapshots {
            prompt += "\n\nCurrent Status:\n"
            if let readiness = snapshots.readiness {
                prompt += "- Overall Readiness: \(String(format: "%.0f%%", readiness.overallReadiness * 100)) (\(readiness.drrsCategory))\n"
            }
            if let funds = snapshots.funds {
                prompt += "- Funds: $\(String(format: "%.0f", funds.remainingAmount)) remaining (\(String(format: "%.0f%%", funds.commitmentRate * 100)) committed)\n"
            }
            if let maint = snapshots.maintenance {
                prompt += "- Equipment MC Rate: \(String(format: "%.0f%%", maint.mcRate * 100))\n"
            }
        }

        prompt += "\n\nProvide your analysis and recommendations."

        return prompt
    }

    /// Parse LLM response into AgentOutput
    internal func parseResponse(_ text: String, input: AgentInput) -> AgentOutput {
        // Basic parsing - subclasses can override for more sophisticated parsing
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }

        var recommendations: [String] = []
        var conflicts: [String] = []
        var confidence = 0.7

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("recommend") || lower.contains("suggest") {
                recommendations.append(line.trimmingCharacters(in: .whitespaces))
            }
            if lower.contains("conflict") || lower.contains("issue") || lower.contains("risk") {
                conflicts.append(line.trimmingCharacters(in: .whitespaces))
            }
            if lower.contains("high confidence") {
                confidence = 0.9
            } else if lower.contains("low confidence") {
                confidence = 0.5
            }
        }

        return AgentOutput(
            summary: text.prefix(1000).description,
            confidence: confidence,
            evidence: [],
            recommendations: recommendations.prefix(5).map { String($0) },
            conflicts: conflicts.prefix(3).map { String($0) }
        )
    }
}

// MARK: - Agent Factory

public struct AgentFactory {
    private let llmClient: LLMClient
    private let config: LLMConfig

    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        self.llmClient = llmClient
        self.config = config
    }

    public func createScribe() -> ScribeAgent {
        ScribeAgent(llmClient: llmClient, config: config)
    }

    public func createCoordinator() -> CoordinatorAgent {
        CoordinatorAgent(llmClient: llmClient, config: config)
    }

    public func createIntegrator() -> IntegratorAgent {
        IntegratorAgent(llmClient: llmClient, config: config)
    }

    public func createEvaluator() -> EvaluatorAgent {
        EvaluatorAgent(llmClient: llmClient, config: config)
    }

    public func createTasking() -> TaskingAgent {
        TaskingAgent(llmClient: llmClient, config: config)
    }

    public func createSpecialist(shop: String, mos: String, name: String) -> SpecialistAgent {
        SpecialistAgent(shop: shop, mos: mos, name: name, llmClient: llmClient, config: config)
    }
}
