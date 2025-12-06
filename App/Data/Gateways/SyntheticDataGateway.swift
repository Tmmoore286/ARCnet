import Foundation
import ARCnetDomain

// MARK: - Synthetic Data Gateway
// MVP implementation using bundled JSON feeds.
// No network calls - all data from repository (pre-imported).

public struct SyntheticDataGateway: DataGateway {
    private let feedRepository: FeedRepository

    public init(feedRepository: FeedRepository) {
        self.feedRepository = feedRepository
    }

    public func readinessSnapshot(for unitId: String) async throws -> ReadinessSnapshot? {
        try await feedRepository.loadReadiness(forUnit: unitId)
    }

    public func readinessHistory(for unitId: String, days: Int) async throws -> [ReadinessSnapshot] {
        try await feedRepository.loadReadinessHistory(forUnit: unitId, limit: days)
    }

    public func fundsSnapshot(for unitId: String) async throws -> FundsSnapshot? {
        try await feedRepository.loadFunds(forUnit: unitId)
    }

    public func fundsHistory(for unitId: String, days: Int) async throws -> [FundsSnapshot] {
        try await feedRepository.loadFundsHistory(forUnit: unitId, limit: days)
    }

    public func maintenanceSnapshot(for unitId: String) async throws -> MaintenanceSnapshot? {
        try await feedRepository.loadMaintenance(forUnit: unitId)
    }

    public func maintenanceHistory(for unitId: String, days: Int) async throws -> [MaintenanceSnapshot] {
        try await feedRepository.loadMaintenanceHistory(forUnit: unitId, limit: days)
    }
}

// MARK: - Synthetic Data Generator
// Generates realistic synthetic data for testing and demos.

public struct SyntheticDataGenerator: Sendable {

    public init() {}

    /// Generate synthetic readiness history for a unit
    public func generateReadinessHistory(
        unitId: String,
        days: Int,
        baseReadiness: Double = 0.85
    ) -> [ReadinessSnapshot] {
        var snapshots: [ReadinessSnapshot] = []
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in (0..<days).reversed() {
            let timestamp = calendar.date(byAdding: .day, value: -dayOffset, to: now)!

            // Add some variance
            let variance = Double.random(in: -0.1...0.1)
            let personnel = min(1.0, max(0.5, baseReadiness + variance + Double.random(in: -0.05...0.05)))
            let equipment = min(1.0, max(0.5, baseReadiness + variance + Double.random(in: -0.08...0.08)))
            let training = min(1.0, max(0.5, baseReadiness + variance + Double.random(in: -0.03...0.03)))
            let overall = (personnel + equipment + training) / 3.0

            let category: String
            switch overall {
            case 0.9...: category = "C1"
            case 0.8..<0.9: category = "C2"
            case 0.7..<0.8: category = "C3"
            default: category = "C4"
            }

            snapshots.append(ReadinessSnapshot(
                unitId: unitId,
                timestamp: timestamp,
                personnelReadiness: personnel,
                equipmentReadiness: equipment,
                trainingReadiness: training,
                overallReadiness: overall,
                drrsCategory: category
            ))
        }

        return snapshots
    }

    /// Generate synthetic funds history for a unit
    public func generateFundsHistory(
        unitId: String,
        fiscalYear: Int,
        days: Int,
        authorizedAmount: Double = 10_000_000
    ) -> [FundsSnapshot] {
        var snapshots: [FundsSnapshot] = []
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in (0..<days).reversed() {
            let timestamp = calendar.date(byAdding: .day, value: -dayOffset, to: now)!

            // Simulate gradual obligation over time
            let progress = Double(days - dayOffset) / Double(days)
            let obligated = authorizedAmount * progress * Double.random(in: 0.85...1.0)
            let expended = obligated * Double.random(in: 0.7...0.9)
            let remaining = authorizedAmount - obligated
            let commitmentRate = obligated / authorizedAmount

            snapshots.append(FundsSnapshot(
                unitId: unitId,
                fiscalYear: fiscalYear,
                timestamp: timestamp,
                authorizedAmount: authorizedAmount,
                obligatedAmount: obligated,
                expendedAmount: expended,
                remainingAmount: remaining,
                commitmentRate: commitmentRate
            ))
        }

        return snapshots
    }

    /// Generate synthetic maintenance history for a unit
    public func generateMaintenanceHistory(
        unitId: String,
        days: Int,
        totalEquipment: Int = 150
    ) -> [MaintenanceSnapshot] {
        var snapshots: [MaintenanceSnapshot] = []
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in (0..<days).reversed() {
            let timestamp = calendar.date(byAdding: .day, value: -dayOffset, to: now)!

            // Simulate maintenance cycles
            let deadlined = Int.random(in: 2...8)
            let awaitingParts = Int.random(in: 5...15)
            let inMaintenance = Int.random(in: 10...25)
            let missionCapable = totalEquipment - deadlined - awaitingParts - inMaintenance
            let mcRate = Double(missionCapable) / Double(totalEquipment)

            snapshots.append(MaintenanceSnapshot(
                unitId: unitId,
                timestamp: timestamp,
                totalEquipment: totalEquipment,
                missionCapable: missionCapable,
                inMaintenance: inMaintenance,
                awaitingParts: awaitingParts,
                deadlined: deadlined,
                mcRate: mcRate
            ))
        }

        return snapshots
    }

    /// Seed a feed repository with synthetic data
    public func seedRepository(
        _ repository: FeedRepository,
        unitId: String,
        days: Int = 90
    ) async throws {
        let readiness = generateReadinessHistory(unitId: unitId, days: days)
        for snapshot in readiness {
            try await repository.saveFeed(snapshot)
        }

        let funds = generateFundsHistory(unitId: unitId, fiscalYear: 2026, days: days)
        for snapshot in funds {
            try await repository.saveFeed(snapshot)
        }

        let maintenance = generateMaintenanceHistory(unitId: unitId, days: days)
        for snapshot in maintenance {
            try await repository.saveFeed(snapshot)
        }
    }
}
