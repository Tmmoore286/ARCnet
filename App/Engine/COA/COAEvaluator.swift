import Foundation
import ARCnetDomain
import ARCnetLLM

// MARK: - Rule-Based COA Evaluator
// Evaluates COAs against scoring rubric using configurable rules.

public struct RuleBasedCOAEvaluator: COAEvaluator {
    public init() {}

    public func evaluate(
        coa: CourseOfAction,
        rubric: ScoringRubric,
        context: MissionContext
    ) async throws -> COAEvaluation {
        var criteriaScores: [EngineCriterionScore] = []

        // Evaluate each criterion in the rubric
        for criterion in rubric.criteria {
            let rawScore = calculateScore(for: criterion.id, coa: coa, context: context)
            criteriaScores.append(EngineCriterionScore(
                criterion: criterion.name,
                weight: criterion.weight,
                rawScore: rawScore,
                rationale: criterion.description
            ))
        }

        // Calculate weighted total
        let weightedScore = criteriaScores.reduce(0.0) { $0 + $1.weightedScore }

        // Identify strengths and weaknesses
        let strengths = identifyStrengths(scores: criteriaScores, coa: coa)
        let weaknesses = identifyWeaknesses(scores: criteriaScores, coa: coa)

        // Assess risks
        let riskAssessments = assessRisks(coa: coa)

        return COAEvaluation(
            coaId: coa.id,
            criteriaScores: criteriaScores,
            weightedScore: weightedScore,
            strengths: strengths,
            weaknesses: weaknesses,
            risks: riskAssessments
        )
    }

    // MARK: - Scoring Calculations

    private func calculateScore(for criterionId: String, coa: CourseOfAction, context: MissionContext) -> Double {
        switch criterionId.lowercased() {
        case "feasibility":
            return calculateFeasibility(coa: coa, context: context)
        case "acceptability":
            return calculateAcceptability(coa: coa, context: context)
        case "suitability":
            return calculateSuitability(coa: coa, context: context)
        case "distinguishability":
            return calculateDistinguishability(coa: coa)
        case "completeness":
            return calculateCompleteness(coa: coa, context: context)
        default:
            return 5.0  // Neutral score for unknown criteria
        }
    }

    private func calculateFeasibility(coa: CourseOfAction, context: MissionContext) -> Double {
        var score = 10.0

        // Deduct for high funding
        if coa.fundingRequired > 200000 {
            score -= 2
        } else if coa.fundingRequired > 100000 {
            score -= 1
        }

        // Deduct for long timeline
        if coa.scheduleImpactDays > 60 {
            score -= 2
        } else if coa.scheduleImpactDays > 30 {
            score -= 1
        }

        // Deduct for high readiness impact
        if coa.readinessImpact > 0.1 {
            score -= 2
        } else if coa.readinessImpact > 0.05 {
            score -= 1
        }

        // Bonus for explicit assumptions
        if coa.assumptions.count >= 2 {
            score += 0.5
        }

        return max(0, min(10, score))
    }

    private func calculateAcceptability(coa: CourseOfAction, context: MissionContext) -> Double {
        var score = 10.0

        // Assess overall risk level
        let highRisks = coa.risks.filter { $0.impact == .high || $0.impact == .critical }.count
        let criticalRisks = coa.risks.filter { $0.likelihood == .high && ($0.impact == .high || $0.impact == .critical) }.count

        score -= Double(highRisks) * 1.5
        score -= Double(criticalRisks) * 2

        // Consider readiness impact on acceptability
        if coa.readinessImpact > 0.15 {
            score -= 2
        }

        return max(0, min(10, score))
    }

    private func calculateSuitability(coa: CourseOfAction, context: MissionContext) -> Double {
        var score = 7.0  // Start neutral

        // Check if description addresses mission elements
        let descLower = coa.description.lowercased()
        let nameLower = coa.name.lowercased()
        let combined = descLower + " " + nameLower

        // Positive indicators
        if combined.contains("objective") || combined.contains("mission") {
            score += 1
        }
        if combined.contains("success") || combined.contains("accomplish") {
            score += 0.5
        }

        // Check alignment with context
        if !context.intent.isEmpty {
            let intentWords = context.intent.lowercased().components(separatedBy: .whitespaces)
            let matches = intentWords.filter { combined.contains($0) }.count
            score += min(2, Double(matches) * 0.5)
        }

        // Deduct if timeline seems misaligned with urgency
        if context.constraints.contains(where: { $0.lowercased().contains("urgent") || $0.lowercased().contains("immediate") }) {
            if coa.scheduleImpactDays > 30 {
                score -= 1.5
            }
        }

        return max(0, min(10, score))
    }

    private func calculateDistinguishability(coa: CourseOfAction) -> Double {
        var score = 7.0

        // Reward descriptive names (not just "COA 1")
        if !coa.name.uppercased().starts(with: "COA ") {
            score += 1
        }

        // Reward detailed description
        if coa.description.count > 50 {
            score += 0.5
        }
        if coa.description.count > 100 {
            score += 0.5
        }

        // Reward multiple assumptions (shows thought)
        score += min(1, Double(coa.assumptions.count) * 0.3)

        return max(0, min(10, score))
    }

    private func calculateCompleteness(coa: CourseOfAction, context: MissionContext) -> Double {
        var score = 6.0

        // Check assumptions coverage
        if coa.assumptions.count >= 2 {
            score += 1
        }
        if coa.assumptions.count >= 4 {
            score += 0.5
        }

        // Check risk identification
        if !coa.risks.isEmpty {
            score += 1
        }
        if coa.risks.count >= 2 {
            score += 0.5
        }

        // Check for numeric details
        if coa.fundingRequired > 0 {
            score += 0.5
        }
        if coa.scheduleImpactDays > 0 {
            score += 0.5
        }

        return max(0, min(10, score))
    }

    // MARK: - Analysis

    private func identifyStrengths(scores: [EngineCriterionScore], coa: CourseOfAction) -> [String] {
        var strengths: [String] = []

        // High-scoring criteria
        for score in scores where score.rawScore >= 8 {
            strengths.append("Strong \(score.criterion.lowercased())")
        }

        // Specific strengths
        if coa.fundingRequired < 75000 {
            strengths.append("Cost-effective approach")
        }
        if coa.scheduleImpactDays < 21 {
            strengths.append("Rapid execution timeline")
        }
        if coa.risks.allSatisfy({ $0.impact != .high && $0.impact != .critical }) {
            strengths.append("Manageable risk profile")
        }

        return strengths
    }

    private func identifyWeaknesses(scores: [EngineCriterionScore], coa: CourseOfAction) -> [String] {
        var weaknesses: [String] = []

        // Low-scoring criteria
        for score in scores where score.rawScore < 6 {
            weaknesses.append("Weak \(score.criterion.lowercased())")
        }

        // Specific weaknesses
        if coa.fundingRequired > 150000 {
            weaknesses.append("High resource requirements")
        }
        if coa.scheduleImpactDays > 45 {
            weaknesses.append("Extended timeline")
        }
        if coa.risks.contains(where: { $0.likelihood == .high && ($0.impact == .high || $0.impact == .critical) }) {
            weaknesses.append("Contains critical risks")
        }
        if coa.assumptions.isEmpty {
            weaknesses.append("Assumptions not clearly stated")
        }

        return weaknesses
    }

    private func assessRisks(coa: CourseOfAction) -> [RiskAssessment] {
        return coa.risks.map { risk in
            RiskAssessment(
                category: categorizeRisk(risk.description),
                description: risk.description,
                likelihood: risk.likelihood,
                impact: risk.impact,
                mitigations: suggestMitigations(for: risk)
            )
        }
    }

    private func categorizeRisk(_ description: String) -> String {
        let lower = description.lowercased()
        if lower.contains("resource") || lower.contains("fund") || lower.contains("budget") {
            return "Resource"
        }
        if lower.contains("time") || lower.contains("schedule") || lower.contains("delay") {
            return "Schedule"
        }
        if lower.contains("personnel") || lower.contains("manpower") || lower.contains("staff") {
            return "Personnel"
        }
        if lower.contains("equipment") || lower.contains("supply") || lower.contains("logistics") {
            return "Logistics"
        }
        if lower.contains("enemy") || lower.contains("threat") || lower.contains("adversary") {
            return "Threat"
        }
        return "Operational"
    }

    private func suggestMitigations(for risk: Risk) -> [String] {
        var mitigations: [String] = []
        let lower = risk.description.lowercased()

        if lower.contains("resource") || lower.contains("fund") {
            mitigations.append("Identify alternative funding sources")
            mitigations.append("Prioritize critical resource allocation")
        }
        if lower.contains("time") || lower.contains("schedule") {
            mitigations.append("Build schedule buffer")
            mitigations.append("Identify parallel execution opportunities")
        }
        if lower.contains("personnel") {
            mitigations.append("Cross-train backup personnel")
            mitigations.append("Request additional support")
        }

        if mitigations.isEmpty {
            mitigations.append("Monitor and reassess regularly")
            mitigations.append("Develop contingency plan")
        }

        return mitigations
    }
}

// MARK: - LLM-Enhanced COA Evaluator

public final class LLMCOAEvaluator: COAEvaluator, @unchecked Sendable {
    private let llmClient: LLMClient
    private let config: LLMConfig
    private let baseEvaluator = RuleBasedCOAEvaluator()

    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        self.llmClient = llmClient
        self.config = config
    }

    public func evaluate(
        coa: CourseOfAction,
        rubric: ScoringRubric,
        context: MissionContext
    ) async throws -> COAEvaluation {
        // Start with rule-based evaluation
        var evaluation = try await baseEvaluator.evaluate(coa: coa, rubric: rubric, context: context)

        // Enhance with LLM analysis for strengths/weaknesses
        let prompt = buildEnhancementPrompt(coa: coa, context: context, baseEvaluation: evaluation)
        let messages = [
            LLMMessage(role: .system, content: "You are a military planning expert. Provide brief analysis of COA strengths and weaknesses."),
            LLMMessage(role: .user, content: prompt)
        ]

        do {
            let response = try await llmClient.complete(messages: messages, config: config)
            let enhanced = parseEnhancements(from: response.text)

            // Merge enhancements
            var strengths = evaluation.strengths
            var weaknesses = evaluation.weaknesses

            strengths.append(contentsOf: enhanced.strengths.filter { !strengths.contains($0) })
            weaknesses.append(contentsOf: enhanced.weaknesses.filter { !weaknesses.contains($0) })

            evaluation = COAEvaluation(
                id: evaluation.id,
                coaId: evaluation.coaId,
                criteriaScores: evaluation.criteriaScores,
                weightedScore: evaluation.weightedScore,
                strengths: strengths,
                weaknesses: weaknesses,
                risks: evaluation.risks,
                evaluatedAt: evaluation.evaluatedAt
            )
        } catch {
            // Fall back to base evaluation if LLM fails
        }

        return evaluation
    }

    private func buildEnhancementPrompt(
        coa: CourseOfAction,
        context: MissionContext,
        baseEvaluation: COAEvaluation
    ) -> String {
        """
        Analyze this Course of Action:

        NAME: \(coa.name)
        DESCRIPTION: \(coa.description)
        TIMELINE: \(coa.scheduleImpactDays) days
        FUNDING: $\(Int(coa.fundingRequired))

        MISSION CONTEXT:
        Intent: \(context.intent)
        End State: \(context.endState)

        Provide 2-3 additional strengths and 2-3 additional weaknesses not already identified:
        Already identified strengths: \(baseEvaluation.strengths.joined(separator: ", "))
        Already identified weaknesses: \(baseEvaluation.weaknesses.joined(separator: ", "))

        Format:
        STRENGTHS:
        - [strength 1]
        WEAKNESSES:
        - [weakness 1]
        """
    }

    private func parseEnhancements(from text: String) -> (strengths: [String], weaknesses: [String]) {
        var strengths: [String] = []
        var weaknesses: [String] = []

        let lines = text.components(separatedBy: "\n")
        var inStrengths = false
        var inWeaknesses = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().contains("STRENGTH") {
                inStrengths = true
                inWeaknesses = false
                continue
            }
            if trimmed.uppercased().contains("WEAKNESS") {
                inStrengths = false
                inWeaknesses = true
                continue
            }

            if trimmed.starts(with: "-") {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if !item.isEmpty {
                    if inStrengths {
                        strengths.append(item)
                    } else if inWeaknesses {
                        weaknesses.append(item)
                    }
                }
            }
        }

        return (strengths, weaknesses)
    }
}
