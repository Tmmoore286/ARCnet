import Foundation
import ARCnetDomain
import ARCnetAgents

// MARK: - COA Tournament Protocol
// Defines interfaces for Course of Action generation, evaluation, and comparison.

/// Protocol for COA generators
public protocol COAGenerator: Sendable {
    /// Generate candidate COAs from integrated assessment
    func generateCOAs(
        assessment: IntegratedAssessment,
        context: MissionContext,
        count: Int
    ) async throws -> [CourseOfAction]
}

/// Protocol for COA evaluators
public protocol COAEvaluator: Sendable {
    /// Score a COA against the rubric criteria
    func evaluate(
        coa: CourseOfAction,
        rubric: ScoringRubric,
        context: MissionContext
    ) async throws -> COAEvaluation
}

/// Protocol for COA comparators (wargaming)
public protocol COAComparator: Sendable {
    /// Compare COAs head-to-head and rank them
    func compare(
        coas: [CourseOfAction],
        evaluations: [COAEvaluation],
        context: MissionContext
    ) async throws -> COARanking
}

/// Integrated assessment from all specialists
public struct IntegratedAssessment: Sendable {
    public let missionStatement: String
    public let specialistAssessments: [SpecialistAssessment]
    public let conflicts: [ConflictItem]
    public let resourceImpacts: ResourceImpacts
    public let recommendations: [String]

    public init(
        missionStatement: String,
        specialistAssessments: [SpecialistAssessment],
        conflicts: [ConflictItem] = [],
        resourceImpacts: ResourceImpacts = ResourceImpacts(),
        recommendations: [String] = []
    ) {
        self.missionStatement = missionStatement
        self.specialistAssessments = specialistAssessments
        self.conflicts = conflicts
        self.resourceImpacts = resourceImpacts
        self.recommendations = recommendations
    }
}

/// A conflict identified between specialist assessments
public struct ConflictItem: Sendable, Identifiable {
    public let id: UUID
    public let shopA: String
    public let shopB: String
    public let description: String
    public let severity: ConflictSeverity
    public let resolution: String?

    public init(
        id: UUID = UUID(),
        shopA: String,
        shopB: String,
        description: String,
        severity: ConflictSeverity,
        resolution: String? = nil
    ) {
        self.id = id
        self.shopA = shopA
        self.shopB = shopB
        self.description = description
        self.severity = severity
        self.resolution = resolution
    }
}

public enum ConflictSeverity: String, Sendable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}

/// Resource impacts summary
public struct ResourceImpacts: Sendable {
    public let personnel: Double  // % change
    public let equipment: Double
    public let funds: Double
    public let schedule: Int  // days

    public init(
        personnel: Double = 0,
        equipment: Double = 0,
        funds: Double = 0,
        schedule: Int = 0
    ) {
        self.personnel = personnel
        self.equipment = equipment
        self.funds = funds
        self.schedule = schedule
    }
}

/// Result of evaluating a COA
public struct COAEvaluation: Sendable, Identifiable {
    public let id: UUID
    public let coaId: UUID
    public let criteriaScores: [EngineCriterionScore]
    public let weightedScore: Double
    public let strengths: [String]
    public let weaknesses: [String]
    public let risks: [RiskAssessment]
    public let evaluatedAt: Date

    public init(
        id: UUID = UUID(),
        coaId: UUID,
        criteriaScores: [EngineCriterionScore],
        weightedScore: Double,
        strengths: [String] = [],
        weaknesses: [String] = [],
        risks: [RiskAssessment] = [],
        evaluatedAt: Date = Date()
    ) {
        self.id = id
        self.coaId = coaId
        self.criteriaScores = criteriaScores
        self.weightedScore = weightedScore
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.risks = risks
        self.evaluatedAt = evaluatedAt
    }
}

/// Score for a single evaluation criterion (Engine-specific)
public struct EngineCriterionScore: Sendable {
    public let criterion: String
    public let weight: Double
    public let rawScore: Double  // 0-10
    public let weightedScore: Double
    public let rationale: String

    public init(
        criterion: String,
        weight: Double,
        rawScore: Double,
        rationale: String = ""
    ) {
        self.criterion = criterion
        self.weight = weight
        self.rawScore = rawScore
        self.weightedScore = rawScore * weight
        self.rationale = rationale
    }
}

/// Risk assessment for a COA
public struct RiskAssessment: Sendable, Identifiable {
    public let id: UUID
    public let category: String
    public let description: String
    public let likelihood: RiskLevel
    public let impact: RiskLevel
    public let mitigations: [String]

    public init(
        id: UUID = UUID(),
        category: String,
        description: String,
        likelihood: RiskLevel,
        impact: RiskLevel,
        mitigations: [String] = []
    ) {
        self.id = id
        self.category = category
        self.description = description
        self.likelihood = likelihood
        self.impact = impact
        self.mitigations = mitigations
    }

    /// Risk score (1-9)
    public var riskScore: Int {
        let likelihoodVal: Int = switch likelihood {
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
        let impactVal: Int = switch impact {
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
        return likelihoodVal * impactVal
    }
}

/// Result of comparing and ranking COAs
public struct COARanking: Sendable {
    public let rankedCOAs: [RankedCOA]
    public let recommendedCOA: UUID
    public let alternativeCOA: UUID?
    public let comparisonNotes: String
    public let decisionFactors: [String]

    public init(
        rankedCOAs: [RankedCOA],
        recommendedCOA: UUID,
        alternativeCOA: UUID? = nil,
        comparisonNotes: String = "",
        decisionFactors: [String] = []
    ) {
        self.rankedCOAs = rankedCOAs
        self.recommendedCOA = recommendedCOA
        self.alternativeCOA = alternativeCOA
        self.comparisonNotes = comparisonNotes
        self.decisionFactors = decisionFactors
    }
}

/// A COA with its ranking position
public struct RankedCOA: Sendable {
    public let coaId: UUID
    public let rank: Int
    public let score: Double
    public let advantageOverNext: Double?
    public let keyStrengths: [String]
    public let keyWeaknesses: [String]

    public init(
        coaId: UUID,
        rank: Int,
        score: Double,
        advantageOverNext: Double? = nil,
        keyStrengths: [String] = [],
        keyWeaknesses: [String] = []
    ) {
        self.coaId = coaId
        self.rank = rank
        self.score = score
        self.advantageOverNext = advantageOverNext
        self.keyStrengths = keyStrengths
        self.keyWeaknesses = keyWeaknesses
    }
}

/// Tournament configuration
public struct TournamentConfig: Sendable {
    public let coaCount: Int
    public let rubric: ScoringRubric
    public let requireWargame: Bool
    public let minScoreDifferential: Double  // Min difference to declare clear winner

    public init(
        coaCount: Int = 3,
        rubric: ScoringRubric = ScoringRubric(),
        requireWargame: Bool = true,
        minScoreDifferential: Double = 0.5
    ) {
        self.coaCount = coaCount
        self.rubric = rubric
        self.requireWargame = requireWargame
        self.minScoreDifferential = minScoreDifferential
    }
}

/// Result of a complete COA tournament
public struct TournamentResult: Sendable {
    public let coas: [CourseOfAction]
    public let evaluations: [COAEvaluation]
    public let ranking: COARanking
    public let selectedCOA: CourseOfAction
    public let alternativeCOA: CourseOfAction?
    public let tournamentDuration: TimeInterval
    public let requiresCommanderDecision: Bool

    public init(
        coas: [CourseOfAction],
        evaluations: [COAEvaluation],
        ranking: COARanking,
        selectedCOA: CourseOfAction,
        alternativeCOA: CourseOfAction? = nil,
        tournamentDuration: TimeInterval,
        requiresCommanderDecision: Bool = false
    ) {
        self.coas = coas
        self.evaluations = evaluations
        self.ranking = ranking
        self.selectedCOA = selectedCOA
        self.alternativeCOA = alternativeCOA
        self.tournamentDuration = tournamentDuration
        self.requiresCommanderDecision = requiresCommanderDecision
    }
}
