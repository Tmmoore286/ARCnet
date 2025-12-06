import Foundation
import ARCnetDomain

// MARK: - Data Gateway Protocol
// Unified interface for accessing command data (readiness, funds, maintenance).
// Implementations can be synthetic (bundled JSON) or live connectors (post-MVP).

public protocol DataGateway: Sendable {
    /// Get current readiness snapshot for a unit
    func readinessSnapshot(for unitId: String) async throws -> ReadinessSnapshot?

    /// Get readiness history for forecasting
    func readinessHistory(for unitId: String, days: Int) async throws -> [ReadinessSnapshot]

    /// Get current funds snapshot for a unit
    func fundsSnapshot(for unitId: String) async throws -> FundsSnapshot?

    /// Get funds history for forecasting
    func fundsHistory(for unitId: String, days: Int) async throws -> [FundsSnapshot]

    /// Get current maintenance snapshot for a unit
    func maintenanceSnapshot(for unitId: String) async throws -> MaintenanceSnapshot?

    /// Get maintenance history for forecasting
    func maintenanceHistory(for unitId: String, days: Int) async throws -> [MaintenanceSnapshot]
}

// MARK: - Gateway Errors

public enum GatewayError: Error, Sendable {
    case notAvailable(String)
    case connectionFailed(String)
    case unauthorized(String)
    case timeout(String)
}
