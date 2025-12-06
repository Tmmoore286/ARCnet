import XCTest
@testable import ARCnetDomain
@testable import ARCnetEngine
@testable import ARCnetData
@testable import ARCnetLLM

final class SelectionTests: XCTestCase {

    // MARK: - Composite Score Tests

    func testCompositeScoreCalculation() {
        let calculator = CompositeScoreCalculator(weights: SelectionWeights())

        let score = calculator.calculate(
            similarityScore: 0.8,
            chainScore: 0.7,
            coverageScore: 0.6,
            availabilityScore: 0.9,
            loadScore: 0.2
        )

        // Expected: 0.3*0.8 + 0.4*0.7 + 0.2*0.6 + 0.1*0.9 - 0.1*0.2
        // = 0.24 + 0.28 + 0.12 + 0.09 - 0.02 = 0.71
        XCTAssertEqual(score, 0.71, accuracy: 0.001)
    }

    func testCompositeScoreOrgWeights() {
        let calculator = CompositeScoreCalculator(weights: .orgDefaults)

        // Org mode favors chain-of-command
        let highChainScore = calculator.calculate(
            similarityScore: 0.5,
            chainScore: 1.0,
            coverageScore: 0.5,
            availabilityScore: 0.5,
            loadScore: 0.0
        )

        let highSimilarityScore = calculator.calculate(
            similarityScore: 1.0,
            chainScore: 0.5,
            coverageScore: 0.5,
            availabilityScore: 0.5,
            loadScore: 0.0
        )

        // High chain should score better in org mode
        XCTAssertGreaterThan(highChainScore, highSimilarityScore)
    }

    func testCompositeScoreMeshWeights() {
        let calculator = CompositeScoreCalculator(weights: .meshDefaults)

        // Mesh mode favors similarity
        let highChainScore = calculator.calculate(
            similarityScore: 0.5,
            chainScore: 1.0,
            coverageScore: 0.5,
            availabilityScore: 0.5,
            loadScore: 0.0
        )

        let highSimilarityScore = calculator.calculate(
            similarityScore: 1.0,
            chainScore: 0.5,
            coverageScore: 0.5,
            availabilityScore: 0.5,
            loadScore: 0.0
        )

        // High similarity should score better in mesh mode
        XCTAssertGreaterThan(highSimilarityScore, highChainScore)
    }

    // MARK: - Chain of Command Scorer Tests

    func testChainOfCommandScoring() {
        let scorer = ChainOfCommandScorer()

        let orgUnit = OrgUnit(
            id: "unit1",
            name: "Test Bn",
            echelon: "Battalion",
            nodes: [
                OrgNode(id: "hq", type: .unit, name: "HQ"),
                OrgNode(id: "s3", type: .section, name: "S-3", parentId: "hq", shop: "S3"),
                OrgNode(id: "ops", type: .billet, name: "Ops Officer", parentId: "s3", shop: "S3", mos: "0302"),
                OrgNode(id: "s4", type: .section, name: "S-4", parentId: "hq", shop: "S4"),
                OrgNode(id: "log", type: .billet, name: "Log Officer", parentId: "s4", shop: "S4", mos: "0402")
            ]
        )

        let missionShops: Set<String> = ["S3"]

        // S3 billet should score highest for S3-relevant mission
        let s3Score = scorer.score(
            node: orgUnit.nodes[2],  // ops officer
            missionShops: missionShops,
            orgTree: orgUnit
        )
        XCTAssertEqual(s3Score, 1.0)

        // S4 billet should score lower
        let s4Score = scorer.score(
            node: orgUnit.nodes[4],  // log officer
            missionShops: missionShops,
            orgTree: orgUnit
        )
        XCTAssertLessThan(s4Score, s3Score)
    }

    // MARK: - Coverage Scorer Tests

    func testCoverageScoring() {
        let scorer = CoverageScorer(requiredShops: ["S3", "S4"])

        let s3Node = OrgNode(id: "n1", type: .billet, name: "Ops", shop: "S3")
        let s4Node = OrgNode(id: "n2", type: .billet, name: "Log", shop: "S4")
        let s2Node = OrgNode(id: "n3", type: .billet, name: "Intel", shop: "S2")

        // First required shop should score highest
        let s3Score = scorer.score(node: s3Node, alreadyCovered: [])
        XCTAssertEqual(s3Score, 1.0)

        // Second required shop should score high
        let s4Score = scorer.score(node: s4Node, alreadyCovered: ["S3"])
        XCTAssertEqual(s4Score, 1.0)

        // Already covered shop should score lower
        let s3CoveredScore = scorer.score(node: s3Node, alreadyCovered: ["S3"])
        XCTAssertLessThan(s3CoveredScore, s3Score)

        // Non-required shop should score lowest
        let s2Score = scorer.score(node: s2Node, alreadyCovered: [])
        XCTAssertLessThan(s2Score, s3Score)
    }

    func testUncoveredShops() {
        let scorer = CoverageScorer(requiredShops: ["S2", "S3", "S4"])

        let uncovered = scorer.uncoveredShops(from: ["S3"])
        XCTAssertEqual(uncovered, ["S2", "S4"])
    }

    // MARK: - Availability Scorer Tests

    func testAvailabilityScoring() {
        let scorer = AvailabilityScorer()

        let autoNode = OrgNode(id: "n1", type: .billet, name: "Auto", autonomy: .auto)
        let hotlNode = OrgNode(id: "n2", type: .billet, name: "HOTL", autonomy: .hotl)
        let hitlNode = OrgNode(id: "n3", type: .billet, name: "HITL", autonomy: .hitl)

        let autoScore = scorer.score(node: autoNode)
        let hotlScore = scorer.score(node: hotlNode)
        let hitlScore = scorer.score(node: hitlNode)

        XCTAssertGreaterThan(autoScore, hotlScore)
        XCTAssertGreaterThan(hotlScore, hitlScore)
    }

    // MARK: - Load Scorer Tests

    func testLoadScoring() {
        let scorer = LoadScorer.withTasks(["agent1": 2, "agent2": 5])

        let lowLoadScore = scorer.score(agentId: "agent1", maxTasks: 5)
        let highLoadScore = scorer.score(agentId: "agent2", maxTasks: 5)
        let noLoadScore = scorer.score(agentId: "agent3", maxTasks: 5)

        XCTAssertEqual(lowLoadScore, 0.4, accuracy: 0.001)
        XCTAssertEqual(highLoadScore, 1.0, accuracy: 0.001)
        XCTAssertEqual(noLoadScore, 0.0, accuracy: 0.001)
    }

    // MARK: - Org Mode Selector Tests

    func testOrgModeSelection() async throws {
        let selector = OrgModeSelector(
            weights: .orgDefaults,
            caps: SelectionCaps(totalAgents: 4, perShop: 1),
            requiredShops: ["S2", "S3", "S4"]
        )

        let orgUnit = createTestOrgUnit()
        let mission = MissionContext(
            intent: "Conduct logistics operation",
            endState: "Supplies delivered"
        )

        let selected = try await selector.select(mission: mission, orgUnit: orgUnit)

        // Should select from required shops
        XCTAssertLessThanOrEqual(selected.count, 4)

        let selectedShops = Set(selected.compactMap(\.shop))
        XCTAssertTrue(selectedShops.isSubset(of: ["S2", "S3", "S4", "S6"]))
    }

    // MARK: - Mesh Mode Selector Tests

    func testMeshModeSelection() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let embeddingService = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let selector = MeshModeSelector(
            embeddingService: embeddingService,
            weights: .meshDefaults,
            caps: SelectionCaps(totalAgents: 4, perShop: 2),
            similarityThreshold: 0.0,  // Accept all for testing
            diversityPenalty: 0.1,
            mustIncludeShops: ["S3"]
        )

        let orgUnit = createTestOrgUnit()
        let mission = MissionContext(
            intent: "Plan tactical operation",
            endState: "Mission complete"
        )

        let selected = try await selector.select(mission: mission, orgUnit: orgUnit)

        // Should select agents
        XCTAssertFalse(selected.isEmpty)
        XCTAssertLessThanOrEqual(selected.count, 4)

        // Must-include shop should be represented
        let selectedShops = Set(selected.compactMap(\.shop))
        XCTAssertTrue(selectedShops.contains("S3"))
    }

    // MARK: - Hybrid Mode Selector Tests

    func testHybridModeSelection() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let embeddingService = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let orgSelector = OrgModeSelector(
            caps: SelectionCaps(totalAgents: 2, perShop: 1),
            requiredShops: ["S3", "S4"]
        )
        let meshSelector = MeshModeSelector(
            embeddingService: embeddingService,
            similarityThreshold: 0.0
        )

        let hybridSelector = HybridModeSelector(
            orgSelector: orgSelector,
            meshSelector: meshSelector,
            caps: SelectionCaps(totalAgents: 4, perShop: 2)
        )

        let orgUnit = createTestOrgUnit()
        let mission = MissionContext(
            intent: "Coordinate multi-shop operation",
            endState: "Operation synchronized"
        )

        let selected = try await hybridSelector.select(mission: mission, orgUnit: orgUnit)

        // Should have mix of org and mesh selections
        XCTAssertFalse(selected.isEmpty)
        XCTAssertLessThanOrEqual(selected.count, 4)
    }

    // MARK: - Flow Advisor Tests

    func testFlowAdvisorOrgRecommendation() {
        let advisor = FlowAdvisor()

        let simpleMission = MissionContext(
            intent: "Submit weekly status report",
            endState: "Report submitted",
            constraints: ["Due by Friday"]
        )

        let recommendation = advisor.recommend(mission: simpleMission)
        XCTAssertEqual(recommendation.mode, .org)
        XCTAssertGreaterThan(recommendation.confidence, 0.5)
    }

    func testFlowAdvisorMeshRecommendation() {
        let advisor = FlowAdvisor()

        let complexMission = MissionContext(
            intent: "Coordinate cross-functional response to multi-domain threat",
            endState: "Integrated response synchronized",
            constraints: [
                "Requires S2/S3/S4 coordination",
                "Must synchronize with adjacent units",
                "Joint asset integration required",
                "Time-sensitive"
            ]
        )

        let recommendation = advisor.recommend(mission: complexMission)
        XCTAssertEqual(recommendation.mode, .mesh)
    }

    func testFlowAdvisorHybridRecommendation() {
        let advisor = FlowAdvisor()

        let moderateMission = MissionContext(
            intent: "Coordinate logistics resupply operation",
            endState: "Resupply complete",
            constraints: ["Must maintain tempo"]
        )

        let recommendation = advisor.recommend(mission: moderateMission)
        XCTAssertEqual(recommendation.mode, .hybrid)
    }

    // MARK: - Default Agent Selector Tests

    func testDefaultAgentSelectorOrgMode() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let embeddingService = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let selector = DefaultAgentSelector(embeddingService: embeddingService)

        let orgUnit = createTestOrgUnit()
        let mission = MissionContext(
            intent: "Standard operation",
            endState: "Complete"
        )

        let selected = try await selector.select(
            mission: mission,
            orgUnit: orgUnit,
            mode: .org
        )

        XCTAssertFalse(selected.isEmpty)
    }

    func testDefaultAgentSelectorMeshMode() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let embeddingService = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let selector = DefaultAgentSelector(embeddingService: embeddingService)

        let orgUnit = createTestOrgUnit()
        let mission = MissionContext(
            intent: "Complex multi-domain operation",
            endState: "Synchronized"
        )

        let selected = try await selector.select(
            mission: mission,
            orgUnit: orgUnit,
            mode: .mesh
        )

        XCTAssertFalse(selected.isEmpty)
    }

    // MARK: - Helper

    private func createTestOrgUnit() -> OrgUnit {
        OrgUnit(
            id: "test-unit",
            name: "Test Battalion",
            echelon: "Battalion",
            nodes: [
                OrgNode(id: "hq", type: .unit, name: "HQ"),
                OrgNode(id: "s2", type: .section, name: "S-2", parentId: "hq", shop: "S2"),
                OrgNode(id: "s2-oic", type: .billet, name: "Intel Officer", parentId: "s2", shop: "S2", mos: "0202", autonomy: .hitl),
                OrgNode(id: "s3", type: .section, name: "S-3", parentId: "hq", shop: "S3"),
                OrgNode(id: "s3-oic", type: .billet, name: "Operations Officer", parentId: "s3", shop: "S3", mos: "0302", autonomy: .hotl),
                OrgNode(id: "s3-fires", type: .billet, name: "Fires Chief", parentId: "s3", shop: "S3", mos: "0861", autonomy: .hotl),
                OrgNode(id: "s4", type: .section, name: "S-4", parentId: "hq", shop: "S4"),
                OrgNode(id: "s4-oic", type: .billet, name: "Logistics Officer", parentId: "s4", shop: "S4", mos: "0402", autonomy: .hitl),
                OrgNode(id: "s4-maint", type: .billet, name: "Maint Chief", parentId: "s4", shop: "S4", mos: "0411", autonomy: .hotl),
                OrgNode(id: "s6", type: .section, name: "S-6", parentId: "hq", shop: "S6"),
                OrgNode(id: "s6-oic", type: .billet, name: "Comms Officer", parentId: "s6", shop: "S6", mos: "0602", autonomy: .hitl)
            ]
        )
    }
}
