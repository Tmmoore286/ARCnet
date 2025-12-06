import Foundation
import ARCnetDomain

// MARK: - Agent Protocol
// Core interface for all ARCnet agents.
// Agents perform bounded, schema-controlled reasoning over mission context.

public protocol Agent: Sendable {
    /// Unique identifier for this agent
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// MOS code if this is a specialist agent (nil for stage agents)
    var mosCode: String? { get }

    /// G-Shop assignment (G1-G9, S1-S6)
    var shop: String? { get }

    /// The MCPP phase this agent operates in
    var mcppPhase: String { get }

    /// Execute the agent's reasoning
    func run(
        input: AgentInput,
        context: MissionContext,
        doctrine: [DoctrineSnippet]
    ) async throws -> AgentOutput
}

// MARK: - Agent Input/Output

public struct AgentInput: Codable, Sendable {
    public var missionStatement: String
    public var priorCheckpoints: [Checkpoint]
    public var specialistAssessments: [SpecialistAssessment]
    public var dataSnapshots: DataSnapshots?

    public init(
        missionStatement: String,
        priorCheckpoints: [Checkpoint] = [],
        specialistAssessments: [SpecialistAssessment] = [],
        dataSnapshots: DataSnapshots? = nil
    ) {
        self.missionStatement = missionStatement
        self.priorCheckpoints = priorCheckpoints
        self.specialistAssessments = specialistAssessments
        self.dataSnapshots = dataSnapshots
    }
}

public struct AgentOutput: Codable, Sendable {
    public var summary: String
    public var confidence: Double
    public var evidence: [Evidence]
    public var recommendations: [String]
    public var conflicts: [String]
    public var requiresApproval: Bool

    public init(
        summary: String,
        confidence: Double = 0.5,
        evidence: [Evidence] = [],
        recommendations: [String] = [],
        conflicts: [String] = [],
        requiresApproval: Bool = true
    ) {
        self.summary = summary
        self.confidence = confidence
        self.evidence = evidence
        self.recommendations = recommendations
        self.conflicts = conflicts
        self.requiresApproval = requiresApproval
    }
}

public struct SpecialistAssessment: Codable, Sendable {
    public var agentId: String
    public var shop: String?
    public var summary: String
    public var confidence: Double
    public var evidence: [Evidence]
    public var recommendations: [String]

    public init(
        agentId: String,
        shop: String? = nil,
        summary: String,
        confidence: Double,
        evidence: [Evidence] = [],
        recommendations: [String] = []
    ) {
        self.agentId = agentId
        self.shop = shop
        self.summary = summary
        self.confidence = confidence
        self.evidence = evidence
        self.recommendations = recommendations
    }
}

public struct DataSnapshots: Codable, Sendable {
    public var readiness: ReadinessSnapshot?
    public var funds: FundsSnapshot?
    public var maintenance: MaintenanceSnapshot?

    public init(
        readiness: ReadinessSnapshot? = nil,
        funds: FundsSnapshot? = nil,
        maintenance: MaintenanceSnapshot? = nil
    ) {
        self.readiness = readiness
        self.funds = funds
        self.maintenance = maintenance
    }
}

public struct DoctrineSnippet: Codable, Sendable {
    public var docId: String
    public var title: String
    public var content: String
    public var section: String?

    public init(docId: String, title: String, content: String, section: String? = nil) {
        self.docId = docId
        self.title = title
        self.content = content
        self.section = section
    }
}

// MARK: - Agent Errors

public enum AgentError: Error, Sendable {
    case llmFailed(String)
    case invalidInput(String)
    case doctrineNotFound(String)
    case timeout(String)
}

// MARK: - Agent Registry

public actor AgentRegistry {
    private var agents: [String: any Agent] = [:]

    public init() {}

    public func register(_ agent: any Agent) {
        agents[agent.id] = agent
    }

    public func get(id: String) -> (any Agent)? {
        agents[id]
    }

    public func all() -> [any Agent] {
        Array(agents.values)
    }

    public func byShop(_ shop: String) -> [any Agent] {
        agents.values.filter { $0.shop == shop }
    }

    public func byMOS(_ mos: String) -> [any Agent] {
        agents.values.filter { $0.mosCode == mos }
    }
}
