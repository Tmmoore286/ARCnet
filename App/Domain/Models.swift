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

