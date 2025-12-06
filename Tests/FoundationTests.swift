import XCTest
@testable import ARCnetDomain
@testable import ARCnetData

final class FoundationTests: XCTestCase {

    // MARK: - Model Tests

    func testOrgNodeCreation() {
        let node = OrgNode(
            id: "B-S3-OPS",
            type: .billet,
            name: "Operations Officer",
            parentId: "S3",
            shop: "S3",
            billet: "Operations Officer",
            mos: "0302",
            agentTemplates: ["ops.coa.gen.v1"],
            autonomy: .hotl
        )

        XCTAssertEqual(node.id, "B-S3-OPS")
        XCTAssertEqual(node.type, .billet)
        XCTAssertEqual(node.mos, "0302")
        XCTAssertEqual(node.autonomy, .hotl)
    }

    func testOrgUnitCreation() {
        let nodes = [
            OrgNode(id: "U1", type: .unit, name: "Bn HQ"),
            OrgNode(id: "S3", type: .section, name: "S-3 Operations", parentId: "U1", shop: "S3")
        ]

        let unit = OrgUnit(
            name: "1st Battalion",
            echelon: "Battalion",
            uic: "BN-0001",
            nodes: nodes
        )

        XCTAssertEqual(unit.name, "1st Battalion")
        XCTAssertEqual(unit.nodes.count, 2)
    }

    func testGatePolicyDefaults() {
        let policy = GatePolicy()

        XCTAssertEqual(policy.gates.count, 4)
        XCTAssertEqual(policy.gates[0].id, "A")
        XCTAssertEqual(policy.gates[0].phase, "problem_framing")
        XCTAssertEqual(policy.autonomyDefaults.billet, .hitl)
    }

    func testSelectionWeights() {
        let orgWeights = SelectionWeights.orgDefaults
        let meshWeights = SelectionWeights.meshDefaults

        // Org mode should favor chain-of-command
        XCTAssertGreaterThan(orgWeights.chain, orgWeights.similarity)

        // Mesh mode should favor similarity
        XCTAssertGreaterThan(meshWeights.similarity, meshWeights.chain)

        // Both should sum to 1.0
        let orgSum = orgWeights.similarity + orgWeights.chain + orgWeights.policy + orgWeights.readiness + orgWeights.load
        let meshSum = meshWeights.similarity + meshWeights.chain + meshWeights.policy + meshWeights.readiness + meshWeights.load
        XCTAssertEqual(orgSum, 1.0, accuracy: 0.001)
        XCTAssertEqual(meshSum, 1.0, accuracy: 0.001)
    }

    func testScoringCriteriaDefaults() {
        let criteria = ScoringCriterion.defaultCriteria

        XCTAssertEqual(criteria.count, 5)

        let totalWeight = criteria.map(\.weight).reduce(0, +)
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }

    // MARK: - Repository Tests

    func testOrgRepositorySaveAndLoad() async throws {
        let repo = InMemoryOrgRepository()

        let unit = OrgUnit(
            id: "test-unit",
            name: "Test Unit",
            echelon: "Battalion",
            nodes: [
                OrgNode(id: "n1", type: .billet, name: "Commander", shop: "S3", mos: "0302")
            ]
        )

        try await repo.saveUnit(unit)
        let loaded = try await repo.loadUnit(id: "test-unit")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Test Unit")
        XCTAssertEqual(loaded?.nodes.count, 1)
    }

    func testOrgRepositoryFindByShop() async throws {
        let repo = InMemoryOrgRepository()

        let unit = OrgUnit(
            id: "test-unit",
            name: "Test Unit",
            echelon: "Battalion",
            nodes: [
                OrgNode(id: "n1", type: .billet, name: "S3 Officer", shop: "S3", mos: "0302"),
                OrgNode(id: "n2", type: .billet, name: "S4 Officer", shop: "S4", mos: "0402"),
                OrgNode(id: "n3", type: .billet, name: "S3 Chief", shop: "S3", mos: "0369")
            ]
        )

        try await repo.saveUnit(unit)
        let s3Nodes = try await repo.findNodes(byShop: "S3")

        XCTAssertEqual(s3Nodes.count, 2)
        XCTAssertTrue(s3Nodes.allSatisfy { $0.shop == "S3" })
    }

    func testMissionRepositorySaveAndAddCheckpoint() async throws {
        let repo = InMemoryMissionRepository()

        var mission = MissionRun(missionStatement: "Test mission")
        try await repo.saveMission(mission)

        let checkpoint = Checkpoint(
            stage: "Scribe",
            agent: "ScribeAgent",
            summary: "Processed mission"
        )
        try await repo.addCheckpoint(checkpoint, toMission: mission.id)

        let loaded = try await repo.loadMission(id: mission.id)
        XCTAssertEqual(loaded?.checkpoints.count, 1)
        XCTAssertEqual(loaded?.checkpoints.first?.stage, "Scribe")
    }

    func testFeedRepositoryReadinessHistory() async throws {
        let repo = InMemoryFeedRepository()

        // Save multiple snapshots
        for i in 0..<5 {
            let snapshot = ReadinessSnapshot(
                unitId: "test-unit",
                timestamp: Date().addingTimeInterval(Double(i) * 3600),
                personnelReadiness: 0.85 + Double(i) * 0.01,
                equipmentReadiness: 0.80,
                trainingReadiness: 0.90,
                overallReadiness: 0.85,
                drrsCategory: "C2"
            )
            try await repo.saveFeed(snapshot)
        }

        let history = try await repo.loadReadinessHistory(forUnit: "test-unit", limit: 3)
        XCTAssertEqual(history.count, 3)

        let latest = try await repo.loadReadiness(forUnit: "test-unit")
        XCTAssertNotNil(latest)
    }

    func testDoctrineRepositoryCentroid() async throws {
        let repo = InMemoryDoctrineRepository()

        // Save vectors for same MOS
        let v1 = DoctrineVector(mosCode: "0302", docId: "doc1", vector: [1.0, 0.0, 0.0])
        let v2 = DoctrineVector(mosCode: "0302", docId: "doc2", vector: [0.0, 1.0, 0.0])
        let v3 = DoctrineVector(mosCode: "0302", docId: "doc3", vector: [0.0, 0.0, 1.0])

        try await repo.saveVector(v1)
        try await repo.saveVector(v2)
        try await repo.saveVector(v3)

        let centroid = try await repo.computeCentroid(forMOS: "0302")
        XCTAssertNotNil(centroid)
        XCTAssertEqual(centroid?.count, 3)

        // Centroid should be average: [0.33, 0.33, 0.33]
        XCTAssertEqual(centroid![0], 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(centroid![1], 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(centroid![2], 1.0/3.0, accuracy: 0.001)
    }

    func testGatePolicyRepository() async throws {
        let repo = InMemoryGatePolicyRepository()

        let gate = try await repo.gateForPhase("problem_framing")
        XCTAssertNotNil(gate)
        XCTAssertEqual(gate?.id, "A")

        let gateC = try await repo.gateForPhase("wargame")
        XCTAssertNotNil(gateC)
        XCTAssertEqual(gateC?.id, "C")
    }

    // MARK: - Importer Tests

    func testOrgImporterFromJSON() async throws {
        let repo = InMemoryOrgRepository()
        let importer = OrgImporter(repository: repo)

        let json = """
        {
          "version": "orgspec.v1",
          "unit": { "name": "Test Bn", "echelon": "Battalion", "uic": "TEST-001" },
          "nodes": [
            { "id": "U1", "type": "unit", "name": "HQ", "parentId": null, "shop": null, "mos": null, "autonomy": "HITL" },
            { "id": "S3", "type": "section", "name": "S-3", "parentId": "U1", "shop": "S3", "mos": null, "autonomy": "HOTL" }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let unit = try await importer.importOrg(from: data)

        XCTAssertEqual(unit.name, "Test Bn")
        XCTAssertEqual(unit.nodes.count, 2)

        let loaded = try await repo.loadUnit(id: "TEST-001")
        XCTAssertNotNil(loaded)
    }

    // MARK: - Gateway Tests

    func testSyntheticDataGateway() async throws {
        let feedRepo = InMemoryFeedRepository()
        let generator = SyntheticDataGenerator()

        // Seed data
        try await generator.seedRepository(feedRepo, unitId: "test-unit", days: 30)

        let gateway = SyntheticDataGateway(feedRepository: feedRepo)

        let readiness = try await gateway.readinessSnapshot(for: "test-unit")
        XCTAssertNotNil(readiness)

        let funds = try await gateway.fundsSnapshot(for: "test-unit")
        XCTAssertNotNil(funds)

        let maintenance = try await gateway.maintenanceSnapshot(for: "test-unit")
        XCTAssertNotNil(maintenance)

        let history = try await gateway.readinessHistory(for: "test-unit", days: 10)
        XCTAssertEqual(history.count, 10)
    }

    // MARK: - COA Model Tests

    func testCOAScoring() {
        let criteria = [
            CriterionScore(criterionName: "Feasibility", weight: 0.25, score: 8.0),
            CriterionScore(criterionName: "Acceptability", weight: 0.25, score: 7.0),
            CriterionScore(criterionName: "Suitability", weight: 0.25, score: 9.0),
            CriterionScore(criterionName: "Distinguishability", weight: 0.15, score: 6.0),
            CriterionScore(criterionName: "Completeness", weight: 0.10, score: 8.0)
        ]

        let totalScore = criteria.map(\.weightedScore).reduce(0, +)

        // Expected: 0.25*8 + 0.25*7 + 0.25*9 + 0.15*6 + 0.10*8 = 2 + 1.75 + 2.25 + 0.9 + 0.8 = 7.7
        XCTAssertEqual(totalScore, 7.7, accuracy: 0.001)
    }

    func testRiskModel() {
        let risk = Risk(
            description: "Equipment failure during operation",
            likelihood: .medium,
            impact: .high,
            mitigation: "Pre-position backup equipment"
        )

        XCTAssertEqual(risk.likelihood, .medium)
        XCTAssertEqual(risk.impact, .high)
        XCTAssertNotNil(risk.mitigation)
    }
}
