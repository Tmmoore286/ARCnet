import Foundation

@MainActor
final class MissionInputViewModel: ObservableObject {
    @Published var missionStatement: String = ""
    @Published var lastCheckpoint: Checkpoint?

    private let orchestrator = StageOrchestrator()

    func start() async {
        let run = MissionRun(missionStatement: missionStatement)
        do {
            let stream = try await orchestrator.runMission(run)
            for await cp in stream {
                lastCheckpoint = cp
            }
        } catch {
            // TODO: surface error to UI in later passes
        }
    }
}

