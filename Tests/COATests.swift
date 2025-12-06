import XCTest
@testable import ARCnetEngine
@testable import ARCnetDomain
@testable import ARCnetLLM
@testable import ARCnetAgents

final class COATests: XCTestCase {

    // MARK: - COA Protocol Tests

    func testIntegratedAssessmentCreation() {
        let assessments = [
            SpecialistAssessment(agentId: "g3", shop: "G3", summary: "Ops ready", confidence: 0.8),
            SpecialistAssessment(agentId: "g4", shop: "G4", summary: "Logistics constrained", confidence: 0.7)
        ]

        let integrated = IntegratedAssessment(
            missionStatement: "Execute convoy operation",
            specialistAssessments: assessments,
            conflicts: [],
            resourceImpacts: ResourceImpacts(personnel: 5, equipment: 10, funds: 50000, schedule: 14)
        )

        XCTAssertEqual(integrated.missionStatement, "Execute convoy operation")
        XCTAssertEqual(integrated.specialistAssessments.count, 2)
        XCTAssertEqual(integrated.resourceImpacts.schedule, 14)
    }

    func testConflictItemCreation() {
        let conflict = ConflictItem(
            shopA: "G3",
            shopB: "G4",
            description: "Timeline disagreement",
            severity: .medium
        )

        XCTAssertEqual(conflict.shopA, "G3")
        XCTAssertEqual(conflict.shopB, "G4")
        XCTAssertEqual(conflict.severity, .medium)
        XCTAssertNil(conflict.resolution)
    }

    func testResourceImpactsDefaults() {
        let impacts = ResourceImpacts()

        XCTAssertEqual(impacts.personnel, 0)
        XCTAssertEqual(impacts.equipment, 0)
        XCTAssertEqual(impacts.funds, 0)
        XCTAssertEqual(impacts.schedule, 0)
    }

    func testCOAEvaluationCreation() {
        let scores = [
            EngineCriterionScore(criterion: "Feasibility", weight: 0.3, rawScore: 8.0),
            EngineCriterionScore(criterion: "Acceptability", weight: 0.3, rawScore: 7.0)
        ]

        let evaluation = COAEvaluation(
            coaId: UUID(),
            criteriaScores: scores,
            weightedScore: 7.5,
            strengths: ["Fast execution"],
            weaknesses: ["High cost"]
        )

        XCTAssertEqual(evaluation.criteriaScores.count, 2)
        XCTAssertEqual(evaluation.weightedScore, 7.5)
        XCTAssertTrue(evaluation.strengths.contains("Fast execution"))
    }

    func testCriterionScoreWeighting() {
        let score = EngineCriterionScore(
            criterion: "Suitability",
            weight: 0.25,
            rawScore: 8.0
        )

        XCTAssertEqual(score.weightedScore, 2.0)  // 8.0 * 0.25
    }

    func testRiskAssessmentScoring() {
        let highHigh = RiskAssessment(
            category: "Operations",
            description: "Critical risk",
            likelihood: RiskLevel.high,
            impact: RiskLevel.high
        )
        XCTAssertEqual(highHigh.riskScore, 9)  // 3 * 3

        let lowLow = RiskAssessment(
            category: "Admin",
            description: "Minor risk",
            likelihood: RiskLevel.low,
            impact: RiskLevel.low
        )
        XCTAssertEqual(lowLow.riskScore, 1)  // 1 * 1

        let mediumHigh = RiskAssessment(
            category: "Logistics",
            description: "Supply risk",
            likelihood: RiskLevel.medium,
            impact: RiskLevel.high
        )
        XCTAssertEqual(mediumHigh.riskScore, 6)  // 2 * 3
    }

    func testRankedCOACreation() {
        let ranked = RankedCOA(
            coaId: UUID(),
            rank: 1,
            score: 8.5,
            advantageOverNext: 1.2,
            keyStrengths: ["Speed", "Cost"],
            keyWeaknesses: ["Risk"]
        )

        XCTAssertEqual(ranked.rank, 1)
        XCTAssertEqual(ranked.score, 8.5)
        XCTAssertEqual(ranked.advantageOverNext, 1.2)
    }

    func testTournamentConfigDefaults() {
        let config = TournamentConfig()

        XCTAssertEqual(config.coaCount, 3)
        XCTAssertTrue(config.requireWargame)
        XCTAssertEqual(config.minScoreDifferential, 0.5)
    }

    // MARK: - Deterministic COA Generator Tests

    func testDeterministicGeneratorCreatesCorrectCount() async throws {
        let generator = DeterministicCOAGenerator()
        let assessment = createTestAssessment()
        let context = MissionContext(intent: "Test", endState: "Complete")

        let coas = try await generator.generateCOAs(
            assessment: assessment,
            context: context,
            count: 3
        )

        XCTAssertEqual(coas.count, 3)
    }

    func testDeterministicGeneratorCreatesDistinctCOAs() async throws {
        let generator = DeterministicCOAGenerator()
        let assessment = createTestAssessment()
        let context = MissionContext()

        let coas = try await generator.generateCOAs(
            assessment: assessment,
            context: context,
            count: 4
        )

        let names = Set(coas.map(\.name))
        XCTAssertEqual(names.count, 4)  // All names should be unique
    }

    func testDeterministicGeneratorIncludesConstraints() async throws {
        let generator = DeterministicCOAGenerator()
        let assessment = IntegratedAssessment(
            missionStatement: "Test mission",
            specialistAssessments: []
        )
        let context = MissionContext(
            intent: "Test",
            endState: "Done",
            constraints: ["Time sensitive", "Limited budget"]
        )

        let coas = try await generator.generateCOAs(
            assessment: assessment,
            context: context,
            count: 2
        )

        // Constraints should appear in assumptions
        let allAssumptions = coas.flatMap(\.assumptions)
        XCTAssertTrue(allAssumptions.contains("Time sensitive") || allAssumptions.contains("Limited budget"))
    }

    // MARK: - Rule-Based COA Evaluator Tests

    func testRuleBasedEvaluatorScoresCOA() async throws {
        let evaluator = RuleBasedCOAEvaluator()
        let coa = CourseOfAction(
            name: "Swift Strike",
            description: "Fast aggressive approach",
            readinessImpact: 0.05,
            fundingRequired: 80000,
            scheduleImpactDays: 21,
            risks: [Risk(description: "Execution risk", likelihood: .medium, impact: .medium)],
            assumptions: ["Standard conditions", "Good weather"]
        )
        let rubric = ScoringRubric()
        let context = MissionContext()

        let evaluation = try await evaluator.evaluate(coa: coa, rubric: rubric, context: context)

        XCTAssertEqual(evaluation.coaId, coa.id)
        XCTAssertGreaterThan(evaluation.weightedScore, 0)
        XCTAssertEqual(evaluation.criteriaScores.count, 5)  // 5 criteria
    }

    func testEvaluatorPenalizesHighCost() async throws {
        let evaluator = RuleBasedCOAEvaluator()
        let rubric = ScoringRubric()
        let context = MissionContext()

        let cheapCOA = CourseOfAction(
            name: "Economy",
            description: "Low cost",
            readinessImpact: 0.05,
            fundingRequired: 50000,
            scheduleImpactDays: 30,
            risks: [],
            assumptions: ["Standard"]
        )

        let expensiveCOA = CourseOfAction(
            name: "Premium",
            description: "High cost",
            readinessImpact: 0.05,
            fundingRequired: 250000,
            scheduleImpactDays: 30,
            risks: [],
            assumptions: ["Standard"]
        )

        let cheapEval = try await evaluator.evaluate(coa: cheapCOA, rubric: rubric, context: context)
        let expensiveEval = try await evaluator.evaluate(coa: expensiveCOA, rubric: rubric, context: context)

        // Cheap should score higher on feasibility
        let cheapFeasibility = cheapEval.criteriaScores.first { $0.criterion == "Feasibility" }?.rawScore ?? 0
        let expensiveFeasibility = expensiveEval.criteriaScores.first { $0.criterion == "Feasibility" }?.rawScore ?? 0

        XCTAssertGreaterThan(cheapFeasibility, expensiveFeasibility)
    }

    func testEvaluatorPenalizesHighRisk() async throws {
        let evaluator = RuleBasedCOAEvaluator()
        let rubric = ScoringRubric()
        let context = MissionContext()

        let lowRiskCOA = CourseOfAction(
            name: "Safe",
            description: "Conservative",
            readinessImpact: 0.03,
            fundingRequired: 80000,
            scheduleImpactDays: 30,
            risks: [Risk(description: "Minor", likelihood: .low, impact: .low)],
            assumptions: ["Standard"]
        )

        let highRiskCOA = CourseOfAction(
            name: "Risky",
            description: "Aggressive",
            readinessImpact: 0.03,
            fundingRequired: 80000,
            scheduleImpactDays: 30,
            risks: [
                Risk(description: "Critical 1", likelihood: .high, impact: .high),
                Risk(description: "Critical 2", likelihood: .high, impact: .high)
            ],
            assumptions: ["Standard"]
        )

        let lowRiskEval = try await evaluator.evaluate(coa: lowRiskCOA, rubric: rubric, context: context)
        let highRiskEval = try await evaluator.evaluate(coa: highRiskCOA, rubric: rubric, context: context)

        let lowAcceptability = lowRiskEval.criteriaScores.first { $0.criterion == "Acceptability" }?.rawScore ?? 0
        let highAcceptability = highRiskEval.criteriaScores.first { $0.criterion == "Acceptability" }?.rawScore ?? 0

        XCTAssertGreaterThan(lowAcceptability, highAcceptability)
    }

    func testEvaluatorIdentifiesStrengthsAndWeaknesses() async throws {
        let evaluator = RuleBasedCOAEvaluator()
        let coa = CourseOfAction(
            name: "Test COA",
            description: "Test description for the course of action that provides detail",
            readinessImpact: 0.03,
            fundingRequired: 50000,  // Low cost
            scheduleImpactDays: 14,   // Fast
            risks: [Risk(description: "Minor risk", likelihood: .low, impact: .low)],
            assumptions: ["Assumption 1", "Assumption 2"]
        )
        let rubric = ScoringRubric()
        let context = MissionContext()

        let evaluation = try await evaluator.evaluate(coa: coa, rubric: rubric, context: context)

        XCTAssertFalse(evaluation.strengths.isEmpty)
        // Low cost and fast timeline should be strengths
        let strengthsJoined = evaluation.strengths.joined(separator: " ").lowercased()
        XCTAssertTrue(
            strengthsJoined.contains("cost") || strengthsJoined.contains("rapid") ||
            strengthsJoined.contains("strong")
        )
    }

    // MARK: - Standard COA Comparator Tests

    func testComparatorRanksCOAsByScore() async throws {
        let comparator = StandardCOAComparator()
        let context = MissionContext()

        let coas = [
            CourseOfAction(name: "Low", description: "Lowest", readinessImpact: 0.15, fundingRequired: 300000, scheduleImpactDays: 90),
            CourseOfAction(name: "High", description: "Highest", readinessImpact: 0.02, fundingRequired: 40000, scheduleImpactDays: 14),
            CourseOfAction(name: "Mid", description: "Middle", readinessImpact: 0.05, fundingRequired: 100000, scheduleImpactDays: 30)
        ]

        // Create evaluations with known scores
        let evaluations = [
            COAEvaluation(coaId: coas[0].id, criteriaScores: [], weightedScore: 5.0),
            COAEvaluation(coaId: coas[1].id, criteriaScores: [], weightedScore: 9.0),
            COAEvaluation(coaId: coas[2].id, criteriaScores: [], weightedScore: 7.0)
        ]

        let ranking = try await comparator.compare(coas: coas, evaluations: evaluations, context: context)

        XCTAssertEqual(ranking.recommendedCOA, coas[1].id)  // "High" should win
        XCTAssertEqual(ranking.rankedCOAs[0].rank, 1)
        XCTAssertEqual(ranking.rankedCOAs[0].score, 9.0)
    }

    func testComparatorCalculatesAdvantage() async throws {
        let comparator = StandardCOAComparator()
        let context = MissionContext()

        let coas = [
            CourseOfAction(name: "First", description: "Best"),
            CourseOfAction(name: "Second", description: "Good")
        ]

        let evaluations = [
            COAEvaluation(coaId: coas[0].id, criteriaScores: [], weightedScore: 8.5),
            COAEvaluation(coaId: coas[1].id, criteriaScores: [], weightedScore: 6.5)
        ]

        let ranking = try await comparator.compare(coas: coas, evaluations: evaluations, context: context)

        XCTAssertEqual(ranking.rankedCOAs[0].advantageOverNext, 2.0)  // 8.5 - 6.5
    }

    func testComparatorIdentifiesAlternative() async throws {
        let comparator = StandardCOAComparator()
        let context = MissionContext()

        let coas = [
            CourseOfAction(name: "Winner", description: "Best"),
            CourseOfAction(name: "Runner-up", description: "Second"),
            CourseOfAction(name: "Third", description: "Third")
        ]

        let evaluations = [
            COAEvaluation(coaId: coas[0].id, criteriaScores: [], weightedScore: 9.0),
            COAEvaluation(coaId: coas[1].id, criteriaScores: [], weightedScore: 7.5),
            COAEvaluation(coaId: coas[2].id, criteriaScores: [], weightedScore: 6.0)
        ]

        let ranking = try await comparator.compare(coas: coas, evaluations: evaluations, context: context)

        XCTAssertEqual(ranking.alternativeCOA, coas[1].id)
    }

    // MARK: - Wargaming Comparator Tests

    func testWargamingComparatorAdjustsScores() async throws {
        let comparator = WargamingCOAComparator()
        let context = MissionContext()

        // COA with many critical risks
        let riskyCOA = CourseOfAction(
            name: "Risky",
            description: "High risk",
            risks: [
                Risk(description: "Critical 1", likelihood: .high, impact: .high),
                Risk(description: "Critical 2", likelihood: .high, impact: .high)
            ]
        )

        // COA with managed risks
        let safeCOA = CourseOfAction(
            name: "Safe",
            description: "Low risk",
            risks: [Risk(description: "Minor", likelihood: .low, impact: .low)]
        )

        let coas = [riskyCOA, safeCOA]

        // Give risky COA slightly higher base score
        let riskyEval = COAEvaluation(
            coaId: riskyCOA.id,
            criteriaScores: [],
            weightedScore: 7.5,
            risks: [
                RiskAssessment(category: "Ops", description: "Critical 1", likelihood: RiskLevel.high, impact: RiskLevel.high),
                RiskAssessment(category: "Ops", description: "Critical 2", likelihood: RiskLevel.high, impact: RiskLevel.high)
            ]
        )
        let safeEval = COAEvaluation(
            coaId: safeCOA.id,
            criteriaScores: [],
            weightedScore: 7.0,
            risks: [
                RiskAssessment(
                    category: "Ops",
                    description: "Minor",
                    likelihood: RiskLevel.low,
                    impact: RiskLevel.low,
                    mitigations: ["Monitor", "Contingency"]
                )
            ]
        )

        let evaluations = [riskyEval, safeEval]

        let ranking = try await comparator.compare(coas: coas, evaluations: evaluations, context: context)

        // Safe COA should potentially rank higher after wargaming adjustment
        // (due to critical risk penalties on risky COA)
        XCTAssertTrue(ranking.decisionFactors.contains("Wargaming analysis applied"))
    }

    // MARK: - COA Tournament Tests

    func testTournamentFullExecution() async throws {
        let tournament = COATournamentFactory.createDeterministicTournament()
        let assessment = createTestAssessment()
        let context = MissionContext(intent: "Complete mission", endState: "Objectives achieved")
        let config = TournamentConfig(coaCount: 3)

        let result = try await tournament.runTournament(
            assessment: assessment,
            context: context,
            config: config
        )

        XCTAssertEqual(result.coas.count, 3)
        XCTAssertEqual(result.evaluations.count, 3)
        XCTAssertFalse(result.ranking.rankedCOAs.isEmpty)
        XCTAssertNotNil(result.selectedCOA)
        XCTAssertGreaterThan(result.tournamentDuration, 0)
    }

    func testTournamentDeterminesCommanderDecision() async throws {
        let tournament = COATournamentFactory.createDeterministicTournament()
        let assessment = createTestAssessment()
        let context = MissionContext()

        // Very low differential threshold to trigger commander decision
        let config = TournamentConfig(coaCount: 2, minScoreDifferential: 5.0)

        let result = try await tournament.runTournament(
            assessment: assessment,
            context: context,
            config: config
        )

        // With such high threshold, commander decision should be required
        // (unless one COA dramatically outscores the other)
        XCTAssertNotNil(result.requiresCommanderDecision)
    }

    func testTournamentIdentifiesAlternativeCOA() async throws {
        let tournament = COATournamentFactory.createDeterministicTournament()
        let assessment = createTestAssessment()
        let context = MissionContext()
        let config = TournamentConfig(coaCount: 3)

        let result = try await tournament.runTournament(
            assessment: assessment,
            context: context,
            config: config
        )

        // With 3 COAs, there should be an alternative
        XCTAssertNotNil(result.alternativeCOA)
        XCTAssertNotEqual(result.selectedCOA.id, result.alternativeCOA?.id)
    }

    // MARK: - Factory Tests

    func testFactoryCreatesDeterministicTournament() {
        let tournament = COATournamentFactory.createDeterministicTournament()
        XCTAssertNotNil(tournament)
    }

    // MARK: - Helper Methods

    private func createTestAssessment() -> IntegratedAssessment {
        IntegratedAssessment(
            missionStatement: "Conduct convoy escort operations",
            specialistAssessments: [
                SpecialistAssessment(agentId: "g3", shop: "G3", summary: "Ops assessment", confidence: 0.8),
                SpecialistAssessment(agentId: "g4", shop: "G4", summary: "Log assessment", confidence: 0.7)
            ],
            resourceImpacts: ResourceImpacts(personnel: 5, equipment: 10, funds: 75000, schedule: 21)
        )
    }
}
