import Foundation

// MARK: - Dual-Judge COA Evaluation
// Uses two independent LLM judges from different providers for robust COA scoring.
// Reduces single-model bias and provides consensus-based confidence.

/// Result from a single judge's evaluation
public struct JudgeScore: Codable, Sendable {
    public var provider: String
    public var model: String
    public var overallScore: Double        // 0.0 - 1.0
    public var criteriaScores: [String: Double]
    public var rationale: String
    public var confidence: Double
    public var evaluationTimeMs: Int

    public init(
        provider: String,
        model: String,
        overallScore: Double,
        criteriaScores: [String: Double],
        rationale: String,
        confidence: Double,
        evaluationTimeMs: Int
    ) {
        self.provider = provider
        self.model = model
        self.overallScore = overallScore
        self.criteriaScores = criteriaScores
        self.rationale = rationale
        self.confidence = confidence
        self.evaluationTimeMs = evaluationTimeMs
    }
}

/// Combined result from dual-judge evaluation
public struct DualJudgeResult: Codable, Sendable {
    public var coaId: String
    public var judge1: JudgeScore
    public var judge2: JudgeScore
    public var consensusScore: Double      // Weighted average
    public var disagreement: Double        // Absolute diff between judges
    public var requiresReview: Bool        // True if high disagreement
    public var combinedRationale: String

    public init(
        coaId: String,
        judge1: JudgeScore,
        judge2: JudgeScore
    ) {
        self.coaId = coaId
        self.judge1 = judge1
        self.judge2 = judge2

        // Calculate consensus (weighted by confidence)
        let totalConfidence = judge1.confidence + judge2.confidence
        self.consensusScore = (judge1.overallScore * judge1.confidence +
                               judge2.overallScore * judge2.confidence) / totalConfidence

        // Calculate disagreement
        self.disagreement = abs(judge1.overallScore - judge2.overallScore)

        // Flag for human review if judges disagree significantly
        self.requiresReview = self.disagreement > 0.2

        // Combine rationales
        self.combinedRationale = """
            Judge 1 (\(judge1.provider)): \(judge1.rationale)

            Judge 2 (\(judge2.provider)): \(judge2.rationale)

            Consensus: \(String(format: "%.2f", self.consensusScore)) \
            (disagreement: \(String(format: "%.2f", self.disagreement)))
            """
    }
}

/// Dual-judge evaluator for COA scoring
public actor DualJudgeEvaluator {
    private let registry: LLMProviderRegistry
    private let client: MultiProviderClient
    private let evaluationCriteria: [EvaluationCriterion]

    public init(
        registry: LLMProviderRegistry,
        criteria: [EvaluationCriterion] = .defaultMilitary
    ) {
        self.registry = registry
        self.client = MultiProviderClient(registry: registry)
        self.evaluationCriteria = criteria
    }

    /// Evaluate a COA using both configured judges
    public func evaluate(
        coa: COAForEvaluation,
        missionContext: String
    ) async throws -> DualJudgeResult {
        let judges = registry.judgeProviders

        guard judges.count >= 2 else {
            throw DualJudgeError.insufficientJudges(
                "Dual-judge requires at least 2 providers, found \(judges.count)"
            )
        }

        // Run both judges concurrently
        async let score1 = evaluateWithProvider(
            coa: coa,
            missionContext: missionContext,
            providerName: judges[0]
        )
        async let score2 = evaluateWithProvider(
            coa: coa,
            missionContext: missionContext,
            providerName: judges[1]
        )

        let (judge1Result, judge2Result) = try await (score1, score2)

        return DualJudgeResult(
            coaId: coa.id,
            judge1: judge1Result,
            judge2: judge2Result
        )
    }

    /// Evaluate a COA with a specific provider
    private func evaluateWithProvider(
        coa: COAForEvaluation,
        missionContext: String,
        providerName: String
    ) async throws -> JudgeScore {
        let startTime = Date()

        let prompt = buildEvaluationPrompt(
            coa: coa,
            missionContext: missionContext,
            criteria: evaluationCriteria
        )

        let messages = [
            LLMMessage(role: .system, content: evaluationSystemPrompt),
            LLMMessage(role: .user, content: prompt)
        ]

        let response = try await client.complete(
            messages: messages,
            providerName: providerName,
            tier: .powerful
        )

        let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

        // Parse the structured response
        let parsed = try parseEvaluationResponse(response.text)

        guard let config = registry.providers[providerName] else {
            throw DualJudgeError.providerNotFound(providerName)
        }

        return JudgeScore(
            provider: providerName,
            model: config.models.powerful,
            overallScore: parsed.overallScore,
            criteriaScores: parsed.criteriaScores,
            rationale: parsed.rationale,
            confidence: parsed.confidence,
            evaluationTimeMs: elapsed
        )
    }

    private var evaluationSystemPrompt: String {
        """
        You are an expert military planning evaluator. Assess courses of action (COAs) \
        against provided criteria. Be objective and thorough.

        Return your evaluation as JSON with this structure:
        {
          "overall_score": 0.75,
          "criteria_scores": {
            "feasibility": 0.8,
            "acceptability": 0.7,
            "suitability": 0.75,
            "completeness": 0.8,
            "distinguishability": 0.7
          },
          "rationale": "Brief explanation of scores...",
          "confidence": 0.85
        }

        Scores range from 0.0 (worst) to 1.0 (best).
        """
    }

    private func buildEvaluationPrompt(
        coa: COAForEvaluation,
        missionContext: String,
        criteria: [EvaluationCriterion]
    ) -> String {
        let criteriaList = criteria.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")

        return """
            ## Mission Context
            \(missionContext)

            ## Course of Action to Evaluate
            **Title:** \(coa.title)
            **Description:** \(coa.description)
            **Key Tasks:**
            \(coa.keyTasks.map { "- \($0)" }.joined(separator: "\n"))

            ## Evaluation Criteria
            \(criteriaList)

            Evaluate this COA against the criteria and mission context.
            """
    }

    private func parseEvaluationResponse(_ text: String) throws -> ParsedEvaluation {
        // Extract JSON from response (may be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: text)

        guard let data = jsonString.data(using: .utf8) else {
            throw DualJudgeError.parseError("Could not convert response to data")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let overallScore = json?["overall_score"] as? Double,
              let criteriaScores = json?["criteria_scores"] as? [String: Double],
              let rationale = json?["rationale"] as? String,
              let confidence = json?["confidence"] as? Double else {
            throw DualJudgeError.parseError("Missing required fields in evaluation response")
        }

        return ParsedEvaluation(
            overallScore: overallScore,
            criteriaScores: criteriaScores,
            rationale: rationale,
            confidence: confidence
        )
    }

    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = text
        if let start = cleaned.range(of: "```json") {
            cleaned = String(cleaned[start.upperBound...])
        } else if let start = cleaned.range(of: "```") {
            cleaned = String(cleaned[start.upperBound...])
        }
        if let end = cleaned.range(of: "```") {
            cleaned = String(cleaned[..<end.lowerBound])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

private struct ParsedEvaluation {
    var overallScore: Double
    var criteriaScores: [String: Double]
    var rationale: String
    var confidence: Double
}

/// A COA prepared for evaluation
public struct COAForEvaluation: Codable, Sendable {
    public var id: String
    public var title: String
    public var description: String
    public var keyTasks: [String]
    public var risks: [String]
    public var resourceRequirements: String

    public init(
        id: String,
        title: String,
        description: String,
        keyTasks: [String],
        risks: [String] = [],
        resourceRequirements: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.keyTasks = keyTasks
        self.risks = risks
        self.resourceRequirements = resourceRequirements
    }
}

/// Evaluation criterion definition
public struct EvaluationCriterion: Codable, Sendable {
    public var name: String
    public var description: String
    public var weight: Double

    public init(name: String, description: String, weight: Double = 1.0) {
        self.name = name
        self.description = description
        self.weight = weight
    }
}

extension Array where Element == EvaluationCriterion {
    /// Standard military COA evaluation criteria
    public static var defaultMilitary: [EvaluationCriterion] {
        [
            EvaluationCriterion(
                name: "Feasibility",
                description: "Can the COA accomplish the mission within time, space, and resource constraints?",
                weight: 1.0
            ),
            EvaluationCriterion(
                name: "Acceptability",
                description: "Is the COA worth the cost in terms of risk, casualties, and resources?",
                weight: 1.0
            ),
            EvaluationCriterion(
                name: "Suitability",
                description: "Does the COA accomplish the mission and comply with guidance?",
                weight: 1.0
            ),
            EvaluationCriterion(
                name: "Completeness",
                description: "Does the COA address who, what, when, where, why, and how?",
                weight: 0.8
            ),
            EvaluationCriterion(
                name: "Distinguishability",
                description: "Is the COA sufficiently different from other options?",
                weight: 0.6
            )
        ]
    }
}

// MARK: - Errors

public enum DualJudgeError: Error, Sendable {
    case insufficientJudges(String)
    case providerNotFound(String)
    case parseError(String)
    case evaluationFailed(String)
}
