import Foundation
import ARCnetDomain

// MARK: - Repository Protocols
// These protocols define the data access layer for ARCnet.
// All data flows through repositories to enforce SSOT (Single Source of Truth).

public protocol OrgRepository: Sendable {
    func loadUnit(id: String) async throws -> OrgUnit?
    func loadAllUnits() async throws -> [OrgUnit]
    func saveUnit(_ unit: OrgUnit) async throws
    func deleteUnit(id: String) async throws
    func findNodes(byShop shop: String) async throws -> [OrgNode]
    func findNodes(byMOS mos: String) async throws -> [OrgNode]
    func findBillets(inUnit unitId: String) async throws -> [OrgNode]
}

public protocol MissionRepository: Sendable {
    func loadMission(id: UUID) async throws -> MissionRun?
    func loadAllMissions() async throws -> [MissionRun]
    func saveMission(_ mission: MissionRun) async throws
    func deleteMission(id: UUID) async throws
    func addCheckpoint(_ checkpoint: Checkpoint, toMission missionId: UUID) async throws
}

public protocol DoctrineRepository: Sendable {
    func loadVector(id: String) async throws -> DoctrineVector?
    func loadVectors(forMOS mos: String) async throws -> [DoctrineVector]
    func loadAllVectors() async throws -> [DoctrineVector]
    func saveVector(_ vector: DoctrineVector) async throws
    func deleteVector(id: String) async throws
    func computeCentroid(forMOS mos: String) async throws -> [Float]?
}

public protocol FeedRepository: Sendable {
    func loadReadiness(forUnit unitId: String) async throws -> ReadinessSnapshot?
    func loadReadinessHistory(forUnit unitId: String, limit: Int) async throws -> [ReadinessSnapshot]
    func saveFeed(_ snapshot: ReadinessSnapshot) async throws

    func loadFunds(forUnit unitId: String) async throws -> FundsSnapshot?
    func loadFundsHistory(forUnit unitId: String, limit: Int) async throws -> [FundsSnapshot]
    func saveFeed(_ snapshot: FundsSnapshot) async throws

    func loadMaintenance(forUnit unitId: String) async throws -> MaintenanceSnapshot?
    func loadMaintenanceHistory(forUnit unitId: String, limit: Int) async throws -> [MaintenanceSnapshot]
    func saveFeed(_ snapshot: MaintenanceSnapshot) async throws

    // Convenience methods for latest snapshots
    func getLatestReadiness(for unitId: String) async -> ReadinessSnapshot?
    func getLatestFunds(for unitId: String) async -> FundsSnapshot?
    func getLatestMaintenance(for unitId: String) async -> MaintenanceSnapshot?
}

public protocol GatePolicyRepository: Sendable {
    func loadPolicy() async throws -> GatePolicy
    func savePolicy(_ policy: GatePolicy) async throws
    func gateForPhase(_ phase: String) async throws -> Gate?

    // Convenience method that doesn't throw
    func getPolicy() async -> GatePolicy
}

// MARK: - Repository Errors

public enum RepositoryError: Error, Sendable {
    case notFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case invalidData(String)
    case loadFailed(String)
}
