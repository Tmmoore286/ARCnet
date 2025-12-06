import Foundation
import ARCnetDomain
import ARCnetData

// MARK: - Gate Enforcer
// Enforces MCPP gate policies based on autonomy mode and authority requirements.

public actor GateEnforcer {
    private let policyRepository: any GatePolicyRepository
    private var gateHistory: [GateHistoryEntry] = []

    public init(policyRepository: any GatePolicyRepository) {
        self.policyRepository = policyRepository
    }

    // MARK: - Gate Enforcement

    /// Enforce a gate checkpoint
    public func enforceGate(
        _ gateId: String,
        checkpoint: Checkpoint,
        autonomyMode: AutonomyMode,
        approver: String? = nil
    ) async throws -> GateResult {
        let policy = await policyRepository.getPolicy()
        guard let gate = policy.gates.first(where: { $0.id == gateId }) else {
            throw GateError.gateNotFound(gateId)
        }

        // Check if gate requires approval
        let requiresPause = shouldPause(
            gate: gate,
            checkpoint: checkpoint,
            autonomyMode: autonomyMode
        )

        // Determine required authority
        let requiredAuthority = parseAuthority(gate.authority)

        // Build result
        let result = GateResult(
            gateId: gateId,
            phase: gate.phase,
            requiresPause: requiresPause,
            requiredAuthority: requiredAuthority,
            confidenceThreshold: getConfidenceThreshold(for: gate),
            checkpointConfidence: checkpoint.confidence,
            meetsThreshold: checkpoint.confidence >= getConfidenceThreshold(for: gate),
            autonomyMode: autonomyMode,
            timestamp: Date()
        )

        // Record in history
        let entry = GateHistoryEntry(
            gateId: gateId,
            checkpointId: checkpoint.id,
            result: result,
            approver: approver,
            timestamp: Date()
        )
        gateHistory.append(entry)

        return result
    }

    /// Approve a gate (called when human approves in HITL mode)
    public func approveGate(
        _ gateId: String,
        approver: String,
        notes: String? = nil
    ) async throws -> GateApproval {
        let approval = GateApproval(
            gateId: gateId,
            approver: approver,
            notes: notes,
            approved: true,
            timestamp: Date()
        )

        // Update history
        if let index = gateHistory.lastIndex(where: { $0.gateId == gateId }) {
            var entry = gateHistory[index]
            entry.approver = approver
            entry.approval = approval
            gateHistory[index] = entry
        }

        return approval
    }

    /// Reject a gate (called when human rejects in HITL mode)
    public func rejectGate(
        _ gateId: String,
        rejecter: String,
        reason: String
    ) async throws -> GateApproval {
        let approval = GateApproval(
            gateId: gateId,
            approver: rejecter,
            notes: reason,
            approved: false,
            timestamp: Date()
        )

        // Update history
        if let index = gateHistory.lastIndex(where: { $0.gateId == gateId }) {
            var entry = gateHistory[index]
            entry.approver = rejecter
            entry.approval = approval
            gateHistory[index] = entry
        }

        return approval
    }

    // MARK: - Gate History

    /// Get history for a specific gate
    public func getHistory(for gateId: String) -> [GateHistoryEntry] {
        gateHistory.filter { $0.gateId == gateId }
    }

    /// Get all gate history
    public func getAllHistory() -> [GateHistoryEntry] {
        gateHistory
    }

    /// Clear history (for testing)
    public func clearHistory() {
        gateHistory.removeAll()
    }

    // MARK: - Private Helpers

    private func shouldPause(
        gate: Gate,
        checkpoint: Checkpoint,
        autonomyMode: AutonomyMode
    ) -> Bool {
        switch autonomyMode {
        case .hitl:
            // Always pause if gate requires approval
            return gate.requiresApproval || checkpoint.requiresApproval

        case .hotl:
            // Only pause for low confidence or critical gates
            if checkpoint.confidence < getConfidenceThreshold(for: gate) {
                return true
            }
            // Critical gates (D) always pause
            return gate.id == "D"

        case .auto:
            // Never pause in auto mode
            return false
        }
    }

    private func getConfidenceThreshold(for gate: Gate) -> Double {
        switch gate.id {
        case "A": return 0.6  // Problem framing - lower threshold
        case "B": return 0.7  // COA development - moderate
        case "C": return 0.75 // Comparison - higher for decision
        case "D": return 0.8  // Orders - highest threshold
        default: return 0.7
        }
    }

    private func parseAuthority(_ authority: String) -> [String] {
        authority.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Gate Result

public struct GateResult: Sendable {
    public let gateId: String
    public let phase: String
    public let requiresPause: Bool
    public let requiredAuthority: [String]
    public let confidenceThreshold: Double
    public let checkpointConfidence: Double
    public let meetsThreshold: Bool
    public let autonomyMode: AutonomyMode
    public let timestamp: Date

    public init(
        gateId: String,
        phase: String,
        requiresPause: Bool,
        requiredAuthority: [String],
        confidenceThreshold: Double,
        checkpointConfidence: Double,
        meetsThreshold: Bool,
        autonomyMode: AutonomyMode,
        timestamp: Date
    ) {
        self.gateId = gateId
        self.phase = phase
        self.requiresPause = requiresPause
        self.requiredAuthority = requiredAuthority
        self.confidenceThreshold = confidenceThreshold
        self.checkpointConfidence = checkpointConfidence
        self.meetsThreshold = meetsThreshold
        self.autonomyMode = autonomyMode
        self.timestamp = timestamp
    }

    /// Whether the gate can auto-proceed
    public var canAutoProceed: Bool {
        !requiresPause && meetsThreshold
    }
}

// MARK: - Gate Approval

public struct GateApproval: Sendable {
    public let gateId: String
    public let approver: String
    public let notes: String?
    public let approved: Bool
    public let timestamp: Date

    public init(
        gateId: String,
        approver: String,
        notes: String?,
        approved: Bool,
        timestamp: Date
    ) {
        self.gateId = gateId
        self.approver = approver
        self.notes = notes
        self.approved = approved
        self.timestamp = timestamp
    }
}

// MARK: - Gate History Entry

public struct GateHistoryEntry: Sendable {
    public var gateId: String
    public var checkpointId: UUID
    public var result: GateResult
    public var approver: String?
    public var approval: GateApproval?
    public var timestamp: Date

    public init(
        gateId: String,
        checkpointId: UUID,
        result: GateResult,
        approver: String? = nil,
        approval: GateApproval? = nil,
        timestamp: Date
    ) {
        self.gateId = gateId
        self.checkpointId = checkpointId
        self.result = result
        self.approver = approver
        self.approval = approval
        self.timestamp = timestamp
    }
}

// MARK: - Gate Errors

public enum GateError: Error, Sendable {
    case gateNotFound(String)
    case approvalRequired(String)
    case insufficientAuthority(String, [String])
    case confidenceBelowThreshold(Double, Double)
}

// MARK: - Mission Characteristics (for Gate decisions)

public enum MissionComplexity: String, Sendable {
    case low
    case medium
    case high
    case critical
}

public enum TimeConstraint: String, Sendable {
    case routine    // Days/weeks
    case standard   // Days
    case urgent     // Hours
    case immediate  // Now
}

public enum ResourceAvailability: String, Sendable {
    case abundant
    case adequate
    case limited
    case critical
}
