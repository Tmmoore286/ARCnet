import Foundation

public protocol StageOrchestrating {
    func runMission(_ mission: MissionRun) async throws -> AsyncStream<Checkpoint>
}

public struct StageOrchestrator: StageOrchestrating {
    public init() {}
    public func runMission(_ mission: MissionRun) async throws -> AsyncStream<Checkpoint> {
        AsyncStream { continuation in
            let cp = Checkpoint(
                stage: "Scribe",
                agent: "ScribeAgent",
                summary: "Mission received: \(mission.missionStatement)",
                confidence: 0.5,
                requiresApproval: true,
                mcppPhase: "problem_framing",
                gate: "A",
                classification: "UNCLASSIFIED"
            )
            continuation.yield(cp)
            continuation.finish()
        }
    }
}

