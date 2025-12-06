import XCTest
@testable import ARCnetDomain
@testable import ARCnetEngine
@testable import ARCnetData
@testable import ARCnetAgents
@testable import ARCnetLLM

// MARK: - Integration Tests
// Tests for the full pipeline orchestration and gate enforcement.

final class IntegrationTests: XCTestCase {

    // MARK: - Gate Enforcer Tests

    func testGateEnforcerCreation() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        // Should not throw
        let history = await enforcer.getAllHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func testGateEnforcerEnforceGateA() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Scribe",
            agent: "scribe",
            summary: "Test checkpoint",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        let result = try await enforcer.enforceGate(
            "A",
            checkpoint: checkpoint,
            autonomyMode: .hitl
        )

        XCTAssertEqual(result.gateId, "A")
        XCTAssertEqual(result.phase, "problem_framing")
        XCTAssertTrue(result.requiresPause)  // HITL always pauses
        XCTAssertTrue(result.meetsThreshold)  // 0.8 > 0.6 threshold
    }

    func testGateEnforcerAutoModeNoPause() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.9,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        let result = try await enforcer.enforceGate(
            "A",
            checkpoint: checkpoint,
            autonomyMode: .auto
        )

        XCTAssertFalse(result.requiresPause)  // Auto mode never pauses
        XCTAssertTrue(result.canAutoProceed)
    }

    func testGateEnforcerHOTLLowConfidencePauses() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.4,  // Below threshold
            mcppPhase: "problem_framing",
            gate: "A"
        )

        let result = try await enforcer.enforceGate(
            "A",
            checkpoint: checkpoint,
            autonomyMode: .hotl
        )

        XCTAssertTrue(result.requiresPause)  // Low confidence triggers pause in HOTL
        XCTAssertFalse(result.meetsThreshold)
    }

    func testGateEnforcerApproval() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        _ = try await enforcer.enforceGate("A", checkpoint: checkpoint, autonomyMode: .hitl)

        let approval = try await enforcer.approveGate("A", approver: "CO", notes: "Approved")

        XCTAssertEqual(approval.gateId, "A")
        XCTAssertEqual(approval.approver, "CO")
        XCTAssertTrue(approval.approved)
    }

    func testGateEnforcerRejection() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        _ = try await enforcer.enforceGate("A", checkpoint: checkpoint, autonomyMode: .hitl)

        let rejection = try await enforcer.rejectGate("A", rejecter: "CO", reason: "Needs more detail")

        XCTAssertEqual(rejection.gateId, "A")
        XCTAssertFalse(rejection.approved)
        XCTAssertEqual(rejection.notes, "Needs more detail")
    }

    func testGateEnforcerHistory() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint1 = Checkpoint(
            stage: "Test1",
            agent: "test",
            summary: "Test 1",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        let checkpoint2 = Checkpoint(
            stage: "Test2",
            agent: "test",
            summary: "Test 2",
            confidence: 0.7,
            mcppPhase: "coa_dev",
            gate: "B"
        )

        _ = try await enforcer.enforceGate("A", checkpoint: checkpoint1, autonomyMode: .hitl)
        _ = try await enforcer.enforceGate("B", checkpoint: checkpoint2, autonomyMode: .hitl)

        let history = await enforcer.getAllHistory()
        XCTAssertEqual(history.count, 2)

        let gateAHistory = await enforcer.getHistory(for: "A")
        XCTAssertEqual(gateAHistory.count, 1)
    }

    func testGateEnforcerClearHistory() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        _ = try await enforcer.enforceGate("A", checkpoint: checkpoint, autonomyMode: .hitl)
        await enforcer.clearHistory()

        let history = await enforcer.getAllHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func testGateEnforcerInvalidGate() async throws {
        let repo = InMemoryGatePolicyRepository()
        let enforcer = GateEnforcer(policyRepository: repo)

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "X"
        )

        do {
            _ = try await enforcer.enforceGate("X", checkpoint: checkpoint, autonomyMode: .hitl)
            XCTFail("Should throw for invalid gate")
        } catch GateError.gateNotFound(let gate) {
            XCTAssertEqual(gate, "X")
        }
    }

    // MARK: - Pipeline Config Tests

    func testPipelineConfigDefaults() {
        let config = PipelineConfig()

        XCTAssertFalse(config.useDeterministicCOA)
        XCTAssertTrue(config.useWargaming)
        XCTAssertEqual(config.maxSpecialists, 9)
        XCTAssertTrue(config.parallelSpecialists)
    }

    func testPipelineConfigCustom() {
        let config = PipelineConfig(
            useDeterministicCOA: true,
            useWargaming: false,
            maxSpecialists: 5,
            parallelSpecialists: false
        )

        XCTAssertTrue(config.useDeterministicCOA)
        XCTAssertFalse(config.useWargaming)
        XCTAssertEqual(config.maxSpecialists, 5)
        XCTAssertFalse(config.parallelSpecialists)
    }

    // MARK: - Pipeline Result Tests

    func testPipelineResultCreation() {
        let coa = CourseOfAction(
            name: "Test COA",
            description: "Test description",
            readinessImpact: 0.05,
            fundingRequired: 50000,
            scheduleImpactDays: 14
        )

        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )

        let result = PipelineResult(
            missionId: UUID(),
            checkpoints: [checkpoint],
            selectedCOA: coa,
            tournamentResult: nil,
            specialistAssessments: [],
            duration: 10.5,
            completedAt: Date()
        )

        XCTAssertEqual(result.checkpoints.count, 1)
        XCTAssertNotNil(result.selectedCOA)
        XCTAssertEqual(result.selectedCOA?.name, "Test COA")
        XCTAssertNil(result.tournamentResult)
        XCTAssertTrue(result.specialistAssessments.isEmpty)
        XCTAssertEqual(result.duration, 10.5)
    }

    // MARK: - Gate Result Tests

    func testGateResultCanAutoProceed() {
        let result1 = GateResult(
            gateId: "A",
            phase: "problem_framing",
            requiresPause: false,
            requiredAuthority: ["CO"],
            confidenceThreshold: 0.6,
            checkpointConfidence: 0.8,
            meetsThreshold: true,
            autonomyMode: .auto,
            timestamp: Date()
        )
        XCTAssertTrue(result1.canAutoProceed)

        let result2 = GateResult(
            gateId: "A",
            phase: "problem_framing",
            requiresPause: true,
            requiredAuthority: ["CO"],
            confidenceThreshold: 0.6,
            checkpointConfidence: 0.8,
            meetsThreshold: true,
            autonomyMode: .hitl,
            timestamp: Date()
        )
        XCTAssertFalse(result2.canAutoProceed)
    }

    // MARK: - Mission Complexity Tests

    func testMissionComplexityEnum() {
        let low = MissionComplexity.low
        let medium = MissionComplexity.medium
        let high = MissionComplexity.high
        let critical = MissionComplexity.critical

        XCTAssertEqual(low.rawValue, "low")
        XCTAssertEqual(medium.rawValue, "medium")
        XCTAssertEqual(high.rawValue, "high")
        XCTAssertEqual(critical.rawValue, "critical")
    }

    func testTimeConstraintEnum() {
        let routine = TimeConstraint.routine
        let standard = TimeConstraint.standard
        let urgent = TimeConstraint.urgent
        let immediate = TimeConstraint.immediate

        XCTAssertEqual(routine.rawValue, "routine")
        XCTAssertEqual(standard.rawValue, "standard")
        XCTAssertEqual(urgent.rawValue, "urgent")
        XCTAssertEqual(immediate.rawValue, "immediate")
    }

    func testResourceAvailabilityEnum() {
        let abundant = ResourceAvailability.abundant
        let adequate = ResourceAvailability.adequate
        let limited = ResourceAvailability.limited
        let critical = ResourceAvailability.critical

        XCTAssertEqual(abundant.rawValue, "abundant")
        XCTAssertEqual(adequate.rawValue, "adequate")
        XCTAssertEqual(limited.rawValue, "limited")
        XCTAssertEqual(critical.rawValue, "critical")
    }

    // MARK: - Pipeline Event Tests

    func testPipelineEventPhaseStarted() {
        let event = PipelineEvent.phaseStarted("problem_framing", "Gate A")
        switch event {
        case .phaseStarted(let phase, let gate):
            XCTAssertEqual(phase, "problem_framing")
            XCTAssertEqual(gate, "Gate A")
        default:
            XCTFail("Wrong event type")
        }
    }

    func testPipelineEventCheckpoint() {
        let checkpoint = Checkpoint(
            stage: "Test",
            agent: "test",
            summary: "Test",
            confidence: 0.8,
            mcppPhase: "problem_framing",
            gate: "A"
        )
        let event = PipelineEvent.checkpoint(checkpoint)
        switch event {
        case .checkpoint(let cp):
            XCTAssertEqual(cp.stage, "Test")
        default:
            XCTFail("Wrong event type")
        }
    }

    func testPipelineEventError() {
        let event = PipelineEvent.error(.executionFailed("Test error"))
        switch event {
        case .error(let error):
            if case .executionFailed(let msg) = error {
                XCTAssertEqual(msg, "Test error")
            } else {
                XCTFail("Wrong error type")
            }
        default:
            XCTFail("Wrong event type")
        }
    }

    // MARK: - Data Gateway Convenience Methods Tests

    func testDataGatewayConvenienceMethods() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)

        // Add some test data
        let readiness = ReadinessSnapshot(
            unitId: "test-unit",
            personnelReadiness: 0.9,
            equipmentReadiness: 0.85,
            trainingReadiness: 0.88,
            overallReadiness: 0.88,
            drrsCategory: "C1"
        )
        try await feedRepo.saveFeed(readiness)

        let funds = FundsSnapshot(
            unitId: "test-unit",
            fiscalYear: 2025,
            authorizedAmount: 1000000,
            obligatedAmount: 500000,
            expendedAmount: 400000,
            remainingAmount: 500000,
            commitmentRate: 0.5
        )
        try await feedRepo.saveFeed(funds)

        let maintenance = MaintenanceSnapshot(
            unitId: "test-unit",
            totalEquipment: 100,
            missionCapable: 85,
            inMaintenance: 10,
            awaitingParts: 3,
            deadlined: 2,
            mcRate: 0.85
        )
        try await feedRepo.saveFeed(maintenance)

        // Test convenience methods
        let r = await gateway.readiness(for: "test-unit")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.overallReadiness, 0.88)

        let f = await gateway.funds(for: "test-unit")
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.commitmentRate, 0.5)

        let m = await gateway.maintenance(for: "test-unit")
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.mcRate, 0.85)

        // Test non-existent unit returns nil
        let none = await gateway.readiness(for: "nonexistent")
        XCTAssertNil(none)
    }

    // MARK: - Repository Convenience Methods Tests

    func testFeedRepositoryConvenienceMethods() async throws {
        let repo = InMemoryFeedRepository()

        let readiness = ReadinessSnapshot(
            unitId: "test",
            personnelReadiness: 0.9,
            equipmentReadiness: 0.85,
            trainingReadiness: 0.88,
            overallReadiness: 0.88,
            drrsCategory: "C1"
        )
        try await repo.saveFeed(readiness)

        let funds = FundsSnapshot(
            unitId: "test",
            fiscalYear: 2025,
            authorizedAmount: 1000000,
            obligatedAmount: 500000,
            expendedAmount: 400000,
            remainingAmount: 500000,
            commitmentRate: 0.5
        )
        try await repo.saveFeed(funds)

        let maintenance = MaintenanceSnapshot(
            unitId: "test",
            totalEquipment: 100,
            missionCapable: 85,
            inMaintenance: 10,
            awaitingParts: 3,
            deadlined: 2,
            mcRate: 0.85
        )
        try await repo.saveFeed(maintenance)

        // Test convenience methods
        let r = await repo.getLatestReadiness(for: "test")
        XCTAssertNotNil(r)

        let f = await repo.getLatestFunds(for: "test")
        XCTAssertNotNil(f)

        let m = await repo.getLatestMaintenance(for: "test")
        XCTAssertNotNil(m)
    }

    func testGatePolicyRepositoryGetPolicy() async {
        let repo = InMemoryGatePolicyRepository()

        let policy = await repo.getPolicy()

        XCTAssertEqual(policy.gates.count, 4)  // A, B, C, D
        XCTAssertEqual(policy.gates.first?.id, "A")
    }
}
