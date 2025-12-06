import XCTest
@testable import ARCnetDomain
@testable import ARCnetEngine

final class EngineTests: XCTestCase {
    func testOrchestratorEmitsCheckpoint() async throws {
        let orch = StageOrchestrator()
        let mission = MissionRun(missionStatement: "Sample mission")
        let stream = try await orch.runMission(mission)
        var received: [Checkpoint] = []
        for await cp in stream { received.append(cp) }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.stage, "Scribe")
    }
}
