import Foundation

public struct MissionRun: Identifiable, Codable, Sendable {
    public var id: UUID
    public var missionStatement: String
    public var acceptanceCriteria: [String]
    public var constraints: [String]
    public var endState: String
    public var checkpoints: [Checkpoint]

    public init(id: UUID = UUID(), missionStatement: String, acceptanceCriteria: [String] = [], constraints: [String] = [], endState: String = "", checkpoints: [Checkpoint] = []) {
        self.id = id
        self.missionStatement = missionStatement
        self.acceptanceCriteria = acceptanceCriteria
        self.constraints = constraints
        self.endState = endState
        self.checkpoints = checkpoints
    }
}

public struct Checkpoint: Identifiable, Codable, Sendable {
    public var id: UUID
    public var stage: String
    public var agent: String
    public var summary: String
    public var confidence: Double
    public var timestamp: Date
    public var requiresApproval: Bool
    public var mcppPhase: String
    public var gate: String
    public var ccir: CCIR?
    public var classification: String
    public var caveats: String?
    public var relTo: String?
    public var evidence: [Evidence]

    public init(id: UUID = UUID(), stage: String, agent: String, summary: String, confidence: Double = 0.0, timestamp: Date = .init(), requiresApproval: Bool = true, mcppPhase: String = "problem_framing", gate: String = "A", ccir: CCIR? = nil, classification: String = "UNCLASSIFIED", caveats: String? = nil, relTo: String? = nil, evidence: [Evidence] = []) {
        self.id = id
        self.stage = stage
        self.agent = agent
        self.summary = summary
        self.confidence = confidence
        self.timestamp = timestamp
        self.requiresApproval = requiresApproval
        self.mcppPhase = mcppPhase
        self.gate = gate
        self.ccir = ccir
        self.classification = classification
        self.caveats = caveats
        self.relTo = relTo
        self.evidence = evidence
    }
}

public struct CCIR: Codable, Sendable {
    public var pir: [String]
    public var ffir: [String]
    public var eefi: [String]
    public init(pir: [String] = [], ffir: [String] = [], eefi: [String] = []) { self.pir = pir; self.ffir = ffir; self.eefi = eefi }
}

public struct Evidence: Codable, Sendable {
    public var docId: String
    public var section: String?
    public var quote: String?
    public init(docId: String, section: String? = nil, quote: String? = nil) { self.docId = docId; self.section = section; self.quote = quote }
}

public struct MissionContext: Codable, Sendable {
    public var intent: String
    public var endState: String
    public var constraints: [String]
    public var acceptanceCriteria: [String]
    public var ccir: CCIR?
    public init(intent: String = "", endState: String = "", constraints: [String] = [], acceptanceCriteria: [String] = [], ccir: CCIR? = nil) {
        self.intent = intent
        self.endState = endState
        self.constraints = constraints
        self.acceptanceCriteria = acceptanceCriteria
        self.ccir = ccir
    }
}

// MARK: - Autonomy Mode

public enum AutonomyMode: String, Codable, Sendable {
    case hitl = "HITL"   // Human-in-the-loop (default): pause for approval
    case hotl = "HOTL"   // Human-on-the-loop: auto-advance, allow intervention
    case auto = "AUTO"   // Autonomous: proceed without prompts
}

// MARK: - Organization Structure Models

public struct OrgUnit: Identifiable, Codable, Sendable {
    public var id: String
    public var name: String
    public var echelon: String
    public var uic: String?
    public var nodes: [OrgNode]

    public init(id: String = UUID().uuidString, name: String, echelon: String, uic: String? = nil, nodes: [OrgNode] = []) {
        self.id = id
        self.name = name
        self.echelon = echelon
        self.uic = uic
        self.nodes = nodes
    }
}

public struct OrgNode: Identifiable, Codable, Sendable {
    public var id: String
    public var type: OrgNodeType
    public var name: String
    public var parentId: String?
    public var echelon: String?
    public var shop: String?
    public var billet: String?
    public var mos: String?
    public var agentTemplates: [String]
    public var autonomy: AutonomyMode
    public var gateAuthority: String?

    public init(
        id: String,
        type: OrgNodeType,
        name: String,
        parentId: String? = nil,
        echelon: String? = nil,
        shop: String? = nil,
        billet: String? = nil,
        mos: String? = nil,
        agentTemplates: [String] = [],
        autonomy: AutonomyMode = .hitl,
        gateAuthority: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.parentId = parentId
        self.echelon = echelon
        self.shop = shop
        self.billet = billet
        self.mos = mos
        self.agentTemplates = agentTemplates
        self.autonomy = autonomy
        self.gateAuthority = gateAuthority
    }
}

public enum OrgNodeType: String, Codable, Sendable {
    case unit
    case section
    case billet
}

// MARK: - Gate Policy

public struct GatePolicy: Codable, Sendable {
    public var version: String
    public var autonomyDefaults: AutonomyDefaults
    public var gates: [Gate]

    public init(version: String = "gate_policy.v1", autonomyDefaults: AutonomyDefaults = .init(), gates: [Gate] = Gate.defaultGates) {
        self.version = version
        self.autonomyDefaults = autonomyDefaults
        self.gates = gates
    }
}

public struct AutonomyDefaults: Codable, Sendable {
    public var billet: AutonomyMode
    public var section: AutonomyMode
    public var unit: AutonomyMode

    public init(billet: AutonomyMode = .hitl, section: AutonomyMode = .hotl, unit: AutonomyMode = .hitl) {
        self.billet = billet
        self.section = section
        self.unit = unit
    }
}

public struct Gate: Identifiable, Codable, Sendable {
    public var id: String
    public var phase: String
    public var authority: String
    public var requiresApproval: Bool

    public init(id: String, phase: String, authority: String, requiresApproval: Bool = true) {
        self.id = id
        self.phase = phase
        self.authority = authority
        self.requiresApproval = requiresApproval
    }

    public static let defaultGates: [Gate] = [
        Gate(id: "A", phase: "problem_framing", authority: "CO"),
        Gate(id: "B", phase: "coa_dev", authority: "XO|CO"),
        Gate(id: "C", phase: "comparison|wargame", authority: "CO"),
        Gate(id: "D", phase: "decision|orders", authority: "CO")
    ]
}

// MARK: - Agent Selection Models

public enum FlowMode: String, Codable, Sendable {
    case org      // Deterministic staff-lane routing
    case mesh     // Similarity-gated expert activation
    case hybrid   // Org for status, Mesh for planning
}

public struct AgentCandidate: Identifiable, Codable, Sendable {
    public var id: String
    public var nodeId: String
    public var name: String
    public var shop: String?
    public var mos: String?
    public var compositeScore: Float
    public var similarityScore: Float
    public var chainScore: Float
    public var coverageScore: Float
    public var availabilityScore: Float
    public var loadScore: Float

    public init(
        id: String = UUID().uuidString,
        nodeId: String,
        name: String,
        shop: String? = nil,
        mos: String? = nil,
        compositeScore: Float = 0,
        similarityScore: Float = 0,
        chainScore: Float = 0,
        coverageScore: Float = 0,
        availabilityScore: Float = 0,
        loadScore: Float = 0
    ) {
        self.id = id
        self.nodeId = nodeId
        self.name = name
        self.shop = shop
        self.mos = mos
        self.compositeScore = compositeScore
        self.similarityScore = similarityScore
        self.chainScore = chainScore
        self.coverageScore = coverageScore
        self.availabilityScore = availabilityScore
        self.loadScore = loadScore
    }
}

public struct SelectionWeights: Codable, Sendable {
    public var similarity: Float
    public var chain: Float
    public var policy: Float
    public var readiness: Float
    public var load: Float

    public init(
        similarity: Float = 0.3,
        chain: Float = 0.4,
        policy: Float = 0.2,
        readiness: Float = 0.1,
        load: Float = 0.1
    ) {
        self.similarity = similarity
        self.chain = chain
        self.policy = policy
        self.readiness = readiness
        self.load = load
    }

    public static let orgDefaults = SelectionWeights(similarity: 0.2, chain: 0.5, policy: 0.2, readiness: 0.05, load: 0.05)
    public static let meshDefaults = SelectionWeights(similarity: 0.5, chain: 0.1, policy: 0.2, readiness: 0.1, load: 0.1)
}

public struct SelectionCaps: Codable, Sendable {
    public var totalAgents: Int
    public var perShop: Int

    public init(totalAgents: Int = 8, perShop: Int = 2) {
        self.totalAgents = totalAgents
        self.perShop = perShop
    }
}

// MARK: - Doctrine & Embeddings

public struct DoctrineVector: Identifiable, Codable, Sendable {
    public var id: String
    public var mosCode: String?
    public var docId: String
    public var vector: [Float]
    public var version: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        mosCode: String? = nil,
        docId: String,
        vector: [Float],
        version: String = "1.0",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.mosCode = mosCode
        self.docId = docId
        self.vector = vector
        self.version = version
        self.createdAt = createdAt
    }
}

// MARK: - Synthetic Data Feed Models

public struct ReadinessSnapshot: Identifiable, Codable, Sendable {
    public var id: String
    public var unitId: String
    public var timestamp: Date
    public var personnelReadiness: Double
    public var equipmentReadiness: Double
    public var trainingReadiness: Double
    public var overallReadiness: Double
    public var drrsCategory: String  // C1, C2, C3, C4

    public init(
        id: String = UUID().uuidString,
        unitId: String,
        timestamp: Date = Date(),
        personnelReadiness: Double,
        equipmentReadiness: Double,
        trainingReadiness: Double,
        overallReadiness: Double,
        drrsCategory: String
    ) {
        self.id = id
        self.unitId = unitId
        self.timestamp = timestamp
        self.personnelReadiness = personnelReadiness
        self.equipmentReadiness = equipmentReadiness
        self.trainingReadiness = trainingReadiness
        self.overallReadiness = overallReadiness
        self.drrsCategory = drrsCategory
    }
}

public struct FundsSnapshot: Identifiable, Codable, Sendable {
    public var id: String
    public var unitId: String
    public var fiscalYear: Int
    public var timestamp: Date
    public var authorizedAmount: Double
    public var obligatedAmount: Double
    public var expendedAmount: Double
    public var remainingAmount: Double
    public var commitmentRate: Double

    public init(
        id: String = UUID().uuidString,
        unitId: String,
        fiscalYear: Int,
        timestamp: Date = Date(),
        authorizedAmount: Double,
        obligatedAmount: Double,
        expendedAmount: Double,
        remainingAmount: Double,
        commitmentRate: Double
    ) {
        self.id = id
        self.unitId = unitId
        self.fiscalYear = fiscalYear
        self.timestamp = timestamp
        self.authorizedAmount = authorizedAmount
        self.obligatedAmount = obligatedAmount
        self.expendedAmount = expendedAmount
        self.remainingAmount = remainingAmount
        self.commitmentRate = commitmentRate
    }
}

public struct MaintenanceSnapshot: Identifiable, Codable, Sendable {
    public var id: String
    public var unitId: String
    public var timestamp: Date
    public var totalEquipment: Int
    public var missionCapable: Int
    public var inMaintenance: Int
    public var awaitingParts: Int
    public var deadlined: Int
    public var mcRate: Double  // Mission Capable Rate

    public init(
        id: String = UUID().uuidString,
        unitId: String,
        timestamp: Date = Date(),
        totalEquipment: Int,
        missionCapable: Int,
        inMaintenance: Int,
        awaitingParts: Int,
        deadlined: Int,
        mcRate: Double
    ) {
        self.id = id
        self.unitId = unitId
        self.timestamp = timestamp
        self.totalEquipment = totalEquipment
        self.missionCapable = missionCapable
        self.inMaintenance = inMaintenance
        self.awaitingParts = awaitingParts
        self.deadlined = deadlined
        self.mcRate = mcRate
    }
}

// MARK: - COA Models

public struct CourseOfAction: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var readinessImpact: Double
    public var fundingRequired: Double
    public var scheduleImpactDays: Int
    public var risks: [Risk]
    public var assumptions: [String]
    public var criteriaScores: [CriterionScore]
    public var totalScore: Double
    public var rank: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        readinessImpact: Double = 0,
        fundingRequired: Double = 0,
        scheduleImpactDays: Int = 0,
        risks: [Risk] = [],
        assumptions: [String] = [],
        criteriaScores: [CriterionScore] = [],
        totalScore: Double = 0,
        rank: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.readinessImpact = readinessImpact
        self.fundingRequired = fundingRequired
        self.scheduleImpactDays = scheduleImpactDays
        self.risks = risks
        self.assumptions = assumptions
        self.criteriaScores = criteriaScores
        self.totalScore = totalScore
        self.rank = rank
    }
}

public struct Risk: Identifiable, Codable, Sendable {
    public var id: UUID
    public var description: String
    public var likelihood: RiskLevel
    public var impact: RiskLevel
    public var mitigation: String?

    public init(id: UUID = UUID(), description: String, likelihood: RiskLevel, impact: RiskLevel, mitigation: String? = nil) {
        self.id = id
        self.description = description
        self.likelihood = likelihood
        self.impact = impact
        self.mitigation = mitigation
    }
}

public enum RiskLevel: String, Codable, Sendable {
    case low, medium, high, critical
}

public struct CriterionScore: Identifiable, Codable, Sendable {
    public var id: UUID
    public var criterionName: String
    public var weight: Double
    public var score: Double
    public var weightedScore: Double
    public var rationale: String?

    public init(id: UUID = UUID(), criterionName: String, weight: Double, score: Double, rationale: String? = nil) {
        self.id = id
        self.criterionName = criterionName
        self.weight = weight
        self.score = score
        self.weightedScore = weight * score
        self.rationale = rationale
    }
}

public struct ScoringRubric: Codable, Sendable {
    public var criteria: [ScoringCriterion]

    public init(criteria: [ScoringCriterion] = ScoringCriterion.defaultCriteria) {
        self.criteria = criteria
    }
}

public struct ScoringCriterion: Identifiable, Codable, Sendable {
    public var id: String
    public var name: String
    public var weight: Double
    public var description: String

    public init(id: String = UUID().uuidString, name: String, weight: Double, description: String) {
        self.id = id
        self.name = name
        self.weight = weight
        self.description = description
    }

    public static let defaultCriteria: [ScoringCriterion] = [
        ScoringCriterion(id: "feasibility", name: "Feasibility", weight: 0.25, description: "Can this COA be accomplished with available resources?"),
        ScoringCriterion(id: "acceptability", name: "Acceptability", weight: 0.25, description: "Is the cost/risk justified by the expected outcome?"),
        ScoringCriterion(id: "suitability", name: "Suitability", weight: 0.25, description: "Does this COA accomplish the mission?"),
        ScoringCriterion(id: "distinguishability", name: "Distinguishability", weight: 0.15, description: "Is this COA significantly different from others?"),
        ScoringCriterion(id: "completeness", name: "Completeness", weight: 0.10, description: "Does this COA address all aspects of the mission?")
    ]
}

// MARK: - Forecast Models

public struct ForecastDataPoint: Identifiable, Codable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var value: Double
    public var isActual: Bool

    public init(id: UUID = UUID(), timestamp: Date, value: Double, isActual: Bool = true) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.isActual = isActual
    }
}

public struct ForecastResult: Codable, Sendable {
    public var metric: String
    public var unitId: String
    public var generatedAt: Date
    public var horizon: Int
    public var predictions: [ForecastDataPoint]
    public var confidence: Double
    public var model: String

    public init(
        metric: String,
        unitId: String,
        generatedAt: Date = Date(),
        horizon: Int,
        predictions: [ForecastDataPoint],
        confidence: Double,
        model: String
    ) {
        self.metric = metric
        self.unitId = unitId
        self.generatedAt = generatedAt
        self.horizon = horizon
        self.predictions = predictions
        self.confidence = confidence
        self.model = model
    }
}

