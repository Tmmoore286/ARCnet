import Foundation
import ARCnetDomain

// MARK: - Synthetic Feed Importer
// Imports synthetic data feeds into the repository.

public struct FeedImporter: Sendable {
    private let repository: FeedRepository

    public init(repository: FeedRepository) {
        self.repository = repository
    }

    // MARK: - Readiness Import

    public func importReadiness(from data: Data) async throws -> [ReadinessSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshots = try decoder.decode([ReadinessSnapshot].self, from: data)
        for snapshot in snapshots {
            try await repository.saveFeed(snapshot)
        }
        return snapshots
    }

    public func importReadiness(from url: URL) async throws -> [ReadinessSnapshot] {
        let data = try Data(contentsOf: url)
        return try await importReadiness(from: data)
    }

    // MARK: - Funds Import

    public func importFunds(from data: Data) async throws -> [FundsSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshots = try decoder.decode([FundsSnapshot].self, from: data)
        for snapshot in snapshots {
            try await repository.saveFeed(snapshot)
        }
        return snapshots
    }

    public func importFunds(from url: URL) async throws -> [FundsSnapshot] {
        let data = try Data(contentsOf: url)
        return try await importFunds(from: data)
    }

    // MARK: - Maintenance Import

    public func importMaintenance(from data: Data) async throws -> [MaintenanceSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshots = try decoder.decode([MaintenanceSnapshot].self, from: data)
        for snapshot in snapshots {
            try await repository.saveFeed(snapshot)
        }
        return snapshots
    }

    public func importMaintenance(from url: URL) async throws -> [MaintenanceSnapshot] {
        let data = try Data(contentsOf: url)
        return try await importMaintenance(from: data)
    }
}
