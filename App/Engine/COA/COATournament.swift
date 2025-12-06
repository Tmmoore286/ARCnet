import Foundation
import ARCnetDomain
import ARCnetLLM

// MARK: - COA Tournament Service
// Orchestrates the full COA generation, evaluation, and comparison process.

public actor COATournament {
    private let generator: COAGenerator
    private let evaluator: COAEvaluator
    private let comparator: COAComparator

    public init(
        generator: COAGenerator,
        evaluator: COAEvaluator,
        comparator: COAComparator
    ) {
        self.generator = generator
        self.evaluator = evaluator
        self.comparator = comparator
    }

    /// Run a complete COA tournament
    public func runTournament(
        assessment: IntegratedAssessment,
        context: MissionContext,
        config: TournamentConfig
    ) async throws -> TournamentResult {
        let startTime = Date()

        // Phase 1: Generate COAs
        let coas = try await generator.generateCOAs(
            assessment: assessment,
            context: context,
            count: config.coaCount
        )

        guard !coas.isEmpty else {
            throw TournamentError.noCoasGenerated
        }

        // Phase 2: Evaluate each COA
        var evaluations: [COAEvaluation] = []
        for coa in coas {
            let evaluation = try await evaluator.evaluate(
                coa: coa,
                rubric: config.rubric,
                context: context
            )
            evaluations.append(evaluation)
        }

        // Phase 3: Compare and rank
        let ranking = try await comparator.compare(
            coas: coas,
            evaluations: evaluations,
            context: context
        )

        // Find selected COA
        guard let selectedCOA = coas.first(where: { $0.id == ranking.recommendedCOA }) else {
            throw TournamentError.coaNotFound(ranking.recommendedCOA)
        }

        let alternativeCOA = ranking.alternativeCOA.flatMap { altId in
            coas.first { $0.id == altId }
        }

        // Determine if commander decision is required
        let requiresDecision = determineIfDecisionRequired(
            ranking: ranking,
            config: config
        )

        let duration = Date().timeIntervalSince(startTime)

        return TournamentResult(
            coas: coas,
            evaluations: evaluations,
            ranking: ranking,
            selectedCOA: selectedCOA,
            alternativeCOA: alternativeCOA,
            tournamentDuration: duration,
            requiresCommanderDecision: requiresDecision
        )
    }

    private func determineIfDecisionRequired(
        ranking: COARanking,
        config: TournamentConfig
    ) -> Bool {
        guard ranking.rankedCOAs.count >= 2 else { return false }

        let topTwo = ranking.rankedCOAs.prefix(2)
        let scoreDiff = (topTwo.first?.score ?? 0) - (topTwo.last?.score ?? 0)

        // If scores are too close, commander should decide
        return scoreDiff < config.minScoreDifferential
    }
}

// MARK: - Standard COA Comparator

public struct StandardCOAComparator: COAComparator {
    public init() {}

    public func compare(
        coas: [CourseOfAction],
        evaluations: [COAEvaluation],
        context: MissionContext
    ) async throws -> COARanking {
        // Create evaluation lookup
        let evalByCoaId = Dictionary(uniqueKeysWithValues: evaluations.map { ($0.coaId, $0) })

        // Sort by weighted score
        let sortedCoas = coas.sorted { coa1, coa2 in
            let score1 = evalByCoaId[coa1.id]?.weightedScore ?? 0
            let score2 = evalByCoaId[coa2.id]?.weightedScore ?? 0
            return score1 > score2
        }

        // Build ranked list
        var rankedCOAs: [RankedCOA] = []
        for (index, coa) in sortedCoas.enumerated() {
            let eval = evalByCoaId[coa.id]
            let score = eval?.weightedScore ?? 0

            // Calculate advantage over next
            var advantageOverNext: Double? = nil
            if index < sortedCoas.count - 1 {
                let nextCoa = sortedCoas[index + 1]
                let nextScore = evalByCoaId[nextCoa.id]?.weightedScore ?? 0
                advantageOverNext = score - nextScore
            }

            rankedCOAs.append(RankedCOA(
                coaId: coa.id,
                rank: index + 1,
                score: score,
                advantageOverNext: advantageOverNext,
                keyStrengths: Array((eval?.strengths ?? []).prefix(3)),
                keyWeaknesses: Array((eval?.weaknesses ?? []).prefix(3))
            ))
        }

        // Identify decision factors
        let decisionFactors = identifyDecisionFactors(
            coas: sortedCoas,
            evaluations: evalByCoaId,
            context: context
        )

        // Build comparison notes
        let comparisonNotes = buildComparisonNotes(rankedCOAs: rankedCOAs, coas: sortedCoas)

        return COARanking(
            rankedCOAs: rankedCOAs,
            recommendedCOA: sortedCoas.first?.id ?? UUID(),
            alternativeCOA: sortedCoas.count > 1 ? sortedCoas[1].id : nil,
            comparisonNotes: comparisonNotes,
            decisionFactors: decisionFactors
        )
    }

    private func identifyDecisionFactors(
        coas: [CourseOfAction],
        evaluations: [UUID: COAEvaluation],
        context: MissionContext
    ) -> [String] {
        var factors: [String] = []

        guard let topCoa = coas.first,
              let topEval = evaluations[topCoa.id] else {
            return factors
        }

        // Score-based factors
        if topEval.weightedScore >= 8 {
            factors.append("Clear winner with strong overall score")
        } else if topEval.weightedScore >= 6 {
            factors.append("Recommended COA has acceptable score")
        } else {
            factors.append("All COAs have moderate scores; careful review recommended")
        }

        // Risk factors
        let highRisks = topEval.risks.filter { $0.riskScore >= 6 }
        if !highRisks.isEmpty {
            factors.append("Top COA contains \(highRisks.count) elevated risk(s)")
        }

        // Time factors
        if context.constraints.contains(where: { $0.lowercased().contains("urgent") }) {
            if topCoa.scheduleImpactDays < 21 {
                factors.append("Timeline aligns with urgency requirement")
            } else {
                factors.append("Timeline may not meet urgency requirement")
            }
        }

        // Cost factors
        if topCoa.fundingRequired > 100000 {
            factors.append("Significant funding commitment required")
        }

        return factors
    }

    private func buildComparisonNotes(rankedCOAs: [RankedCOA], coas: [CourseOfAction]) -> String {
        guard let top = rankedCOAs.first else { return "No COAs to compare" }

        var notes = "Recommended: "
        if let topCoa = coas.first(where: { $0.id == top.coaId }) {
            notes += "\(topCoa.name) (Score: \(String(format: "%.1f", top.score)))"
        }

        if rankedCOAs.count > 1, let advantage = top.advantageOverNext {
            if advantage < 0.5 {
                notes += ". Close margin with #2 - commander review advised."
            } else if advantage < 1.0 {
                notes += ". Moderate advantage over alternatives."
            } else {
                notes += ". Clear advantage over alternatives."
            }
        }

        return notes
    }
}

// MARK: - Wargaming Comparator

/// Comparator that uses simulated wargaming for deeper analysis
public struct WargamingCOAComparator: COAComparator {
    private let baseComparator = StandardCOAComparator()

    public init() {}

    public func compare(
        coas: [CourseOfAction],
        evaluations: [COAEvaluation],
        context: MissionContext
    ) async throws -> COARanking {
        // Start with standard ranking
        var ranking = try await baseComparator.compare(
            coas: coas,
            evaluations: evaluations,
            context: context
        )

        // Apply wargame adjustments
        let wargameResults = simulateWargame(coas: coas, evaluations: evaluations)

        // Adjust scores based on wargame
        var adjustedRanked: [RankedCOA] = []
        for (index, ranked) in ranking.rankedCOAs.enumerated() {
            let adjustment = wargameResults[ranked.coaId] ?? 0
            let newScore = ranked.score + adjustment

            adjustedRanked.append(RankedCOA(
                coaId: ranked.coaId,
                rank: index + 1,  // Will re-rank after
                score: newScore,
                advantageOverNext: nil,
                keyStrengths: ranked.keyStrengths,
                keyWeaknesses: ranked.keyWeaknesses
            ))
        }

        // Re-sort by adjusted score
        adjustedRanked.sort { $0.score > $1.score }

        // Recalculate ranks and advantages
        var finalRanked: [RankedCOA] = []
        for (index, ranked) in adjustedRanked.enumerated() {
            var advantageOverNext: Double? = nil
            if index < adjustedRanked.count - 1 {
                advantageOverNext = ranked.score - adjustedRanked[index + 1].score
            }

            finalRanked.append(RankedCOA(
                coaId: ranked.coaId,
                rank: index + 1,
                score: ranked.score,
                advantageOverNext: advantageOverNext,
                keyStrengths: ranked.keyStrengths,
                keyWeaknesses: ranked.keyWeaknesses
            ))
        }

        // Update ranking
        var decisionFactors = ranking.decisionFactors
        decisionFactors.insert("Wargaming analysis applied", at: 0)

        return COARanking(
            rankedCOAs: finalRanked,
            recommendedCOA: finalRanked.first?.coaId ?? ranking.recommendedCOA,
            alternativeCOA: finalRanked.count > 1 ? finalRanked[1].coaId : nil,
            comparisonNotes: ranking.comparisonNotes + " (Wargame-adjusted)",
            decisionFactors: decisionFactors
        )
    }

    private func simulateWargame(
        coas: [CourseOfAction],
        evaluations: [COAEvaluation]
    ) -> [UUID: Double] {
        var adjustments: [UUID: Double] = [:]

        let evalByCoaId = Dictionary(uniqueKeysWithValues: evaluations.map { ($0.coaId, $0) })

        for coa in coas {
            var adjustment = 0.0

            // Penalize high-risk COAs more in wargaming
            if let eval = evalByCoaId[coa.id] {
                let criticalRisks = eval.risks.filter { $0.riskScore >= 6 }
                adjustment -= Double(criticalRisks.count) * 0.3
            }

            // Reward COAs with more mitigation options
            if let eval = evalByCoaId[coa.id] {
                let totalMitigations = eval.risks.reduce(0) { $0 + $1.mitigations.count }
                adjustment += Double(totalMitigations) * 0.1
            }

            // Apply timeline pressure
            if coa.scheduleImpactDays > 45 {
                adjustment -= 0.5  // Long timelines are vulnerable
            } else if coa.scheduleImpactDays < 21 {
                adjustment += 0.3  // Fast execution has advantages
            }

            adjustments[coa.id] = adjustment
        }

        return adjustments
    }
}

// MARK: - Tournament Errors

public enum TournamentError: Error {
    case noCoasGenerated
    case coaNotFound(UUID)
    case evaluationFailed(String)
    case comparisonFailed(String)
}

// MARK: - Convenience Factory

public struct COATournamentFactory {
    public static func createStandardTournament(llmClient: LLMClient) -> COATournament {
        COATournament(
            generator: LLMCOAGenerator(llmClient: llmClient),
            evaluator: RuleBasedCOAEvaluator(),
            comparator: StandardCOAComparator()
        )
    }

    public static func createDeterministicTournament() -> COATournament {
        COATournament(
            generator: DeterministicCOAGenerator(),
            evaluator: RuleBasedCOAEvaluator(),
            comparator: StandardCOAComparator()
        )
    }

    public static func createWargamingTournament(llmClient: LLMClient) -> COATournament {
        COATournament(
            generator: LLMCOAGenerator(llmClient: llmClient),
            evaluator: LLMCOAEvaluator(llmClient: llmClient),
            comparator: WargamingCOAComparator()
        )
    }
}
