import Foundation
import ARCnetDomain

// MARK: - In-Memory Implementations
// These are thread-safe in-memory implementations for MVP/testing.
// Production will swap these for CoreData-backed implementations.

public actor InMemoryOrgRepository: OrgRepository {
    private var units: [String: OrgUnit] = [:]

    public init() {}

    public func loadUnit(id: String) async throws -> OrgUnit? {
        units[id]
    }

    public func loadAllUnits() async throws -> [OrgUnit] {
        Array(units.values)
    }

    public func saveUnit(_ unit: OrgUnit) async throws {
        units[unit.id] = unit
    }

    public func deleteUnit(id: String) async throws {
        guard units.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound("Unit \(id) not found")
        }
    }

    public func findNodes(byShop shop: String) async throws -> [OrgNode] {
        units.values.flatMap { $0.nodes.filter { $0.shop == shop } }
    }

    public func findNodes(byMOS mos: String) async throws -> [OrgNode] {
        units.values.flatMap { $0.nodes.filter { $0.mos == mos } }
    }

    public func findBillets(inUnit unitId: String) async throws -> [OrgNode] {
        guard let unit = units[unitId] else { return [] }
        return unit.nodes.filter { $0.type == .billet }
    }
}

public actor InMemoryMissionRepository: MissionRepository {
    private var missions: [UUID: MissionRun] = [:]

    public init() {}

    public func loadMission(id: UUID) async throws -> MissionRun? {
        missions[id]
    }

    public func loadAllMissions() async throws -> [MissionRun] {
        Array(missions.values)
    }

    public func saveMission(_ mission: MissionRun) async throws {
        missions[mission.id] = mission
    }

    public func deleteMission(id: UUID) async throws {
        guard missions.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound("Mission \(id) not found")
        }
    }

    public func addCheckpoint(_ checkpoint: Checkpoint, toMission missionId: UUID) async throws {
        guard var mission = missions[missionId] else {
            throw RepositoryError.notFound("Mission \(missionId) not found")
        }
        mission.checkpoints.append(checkpoint)
        missions[missionId] = mission
    }
}

public actor InMemoryDoctrineRepository: DoctrineRepository {
    private var vectors: [String: DoctrineVector] = [:]

    public init() {}

    public func loadVector(id: String) async throws -> DoctrineVector? {
        vectors[id]
    }

    public func loadVectors(forMOS mos: String) async throws -> [DoctrineVector] {
        vectors.values.filter { $0.mosCode == mos }
    }

    public func loadAllVectors() async throws -> [DoctrineVector] {
        Array(vectors.values)
    }

    public func saveVector(_ vector: DoctrineVector) async throws {
        vectors[vector.id] = vector
    }

    public func deleteVector(id: String) async throws {
        guard vectors.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound("Vector \(id) not found")
        }
    }

    public func computeCentroid(forMOS mos: String) async throws -> [Float]? {
        let mosVectors = vectors.values.filter { $0.mosCode == mos }
        guard !mosVectors.isEmpty else { return nil }

        let dimension = mosVectors.first!.vector.count
        var centroid = [Float](repeating: 0, count: dimension)

        for v in mosVectors {
            for (i, val) in v.vector.enumerated() where i < dimension {
                centroid[i] += val
            }
        }

        let count = Float(mosVectors.count)
        return centroid.map { $0 / count }
    }
}

public actor InMemoryFeedRepository: FeedRepository {
    private var readinessSnapshots: [String: [ReadinessSnapshot]] = [:]
    private var fundsSnapshots: [String: [FundsSnapshot]] = [:]
    private var maintenanceSnapshots: [String: [MaintenanceSnapshot]] = [:]

    public init() {}

    // MARK: - Readiness

    public func loadReadiness(forUnit unitId: String) async throws -> ReadinessSnapshot? {
        readinessSnapshots[unitId]?.last
    }

    public func loadReadinessHistory(forUnit unitId: String, limit: Int) async throws -> [ReadinessSnapshot] {
        let history = readinessSnapshots[unitId] ?? []
        return Array(history.suffix(limit))
    }

    public func saveFeed(_ snapshot: ReadinessSnapshot) async throws {
        var history = readinessSnapshots[snapshot.unitId] ?? []
        history.append(snapshot)
        readinessSnapshots[snapshot.unitId] = history
    }

    // MARK: - Funds

    public func loadFunds(forUnit unitId: String) async throws -> FundsSnapshot? {
        fundsSnapshots[unitId]?.last
    }

    public func loadFundsHistory(forUnit unitId: String, limit: Int) async throws -> [FundsSnapshot] {
        let history = fundsSnapshots[unitId] ?? []
        return Array(history.suffix(limit))
    }

    public func saveFeed(_ snapshot: FundsSnapshot) async throws {
        var history = fundsSnapshots[snapshot.unitId] ?? []
        history.append(snapshot)
        fundsSnapshots[snapshot.unitId] = history
    }

    // MARK: - Maintenance

    public func loadMaintenance(forUnit unitId: String) async throws -> MaintenanceSnapshot? {
        maintenanceSnapshots[unitId]?.last
    }

    public func loadMaintenanceHistory(forUnit unitId: String, limit: Int) async throws -> [MaintenanceSnapshot] {
        let history = maintenanceSnapshots[unitId] ?? []
        return Array(history.suffix(limit))
    }

    public func saveFeed(_ snapshot: MaintenanceSnapshot) async throws {
        var history = maintenanceSnapshots[snapshot.unitId] ?? []
        history.append(snapshot)
        maintenanceSnapshots[snapshot.unitId] = history
    }

    // MARK: - Convenience Methods

    public func getLatestReadiness(for unitId: String) async -> ReadinessSnapshot? {
        readinessSnapshots[unitId]?.last
    }

    public func getLatestFunds(for unitId: String) async -> FundsSnapshot? {
        fundsSnapshots[unitId]?.last
    }

    public func getLatestMaintenance(for unitId: String) async -> MaintenanceSnapshot? {
        maintenanceSnapshots[unitId]?.last
    }
}

public actor InMemoryGatePolicyRepository: GatePolicyRepository {
    private var policy: GatePolicy = GatePolicy()

    public init() {}

    public func loadPolicy() async throws -> GatePolicy {
        policy
    }

    public func savePolicy(_ policy: GatePolicy) async throws {
        self.policy = policy
    }

    public func gateForPhase(_ phase: String) async throws -> Gate? {
        policy.gates.first { gate in
            gate.phase.split(separator: "|").map(String.init).contains(phase)
        }
    }

    public func getPolicy() async -> GatePolicy {
        policy
    }
}
