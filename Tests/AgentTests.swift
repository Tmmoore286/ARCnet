import XCTest
@testable import ARCnetDomain
@testable import ARCnetAgents
@testable import ARCnetLLM

// MARK: - Mock LLM Client for Testing

struct MockLLMClient: LLMClient {
    let response: String

    init(response: String = "Test response with recommendation to proceed.") {
        self.response = response
    }

    func complete(messages: [LLMMessage], config: LLMConfig) async throws -> LLMResponse {
        LLMResponse(text: response)
    }
}

final class AgentTests: XCTestCase {

    // MARK: - Base Agent Tests

    func testBaseAgentCreation() {
        let client = MockLLMClient()
        let agent = BaseAgent(
            id: "test-agent",
            name: "Test Agent",
            mcppPhase: "problem_framing",
            llmClient: client
        )

        XCTAssertEqual(agent.id, "test-agent")
        XCTAssertEqual(agent.name, "Test Agent")
        XCTAssertEqual(agent.mcppPhase, "problem_framing")
        XCTAssertNil(agent.mosCode)
        XCTAssertNil(agent.shop)
    }

    func testBaseAgentRun() async throws {
        let client = MockLLMClient(response: """
            Analysis complete.
            Recommend proceeding with the operation.
            High confidence in assessment.
            """)
        let agent = BaseAgent(
            id: "test",
            name: "Test",
            mcppPhase: "test",
            llmClient: client
        )

        let input = AgentInput(missionStatement: "Test mission")
        let context = MissionContext(intent: "Test", endState: "Complete")

        let output = try await agent.run(input: input, context: context, doctrine: [])

        XCTAssertFalse(output.summary.isEmpty)
        XCTAssertGreaterThan(output.confidence, 0)
    }

    // MARK: - Stage Agent Tests

    func testScribeAgentCreation() {
        let client = MockLLMClient()
        let scribe = ScribeAgent(llmClient: client)

        XCTAssertEqual(scribe.id, "scribe")
        XCTAssertEqual(scribe.mcppPhase, "problem_framing")
    }

    func testScribeAgentRun() async throws {
        let client = MockLLMClient(response: """
            MISSION STATEMENT: Conduct convoy escort operations

            CONSTRAINTS:
            - Limited personnel available
            - Time-sensitive

            ACCEPTANCE CRITERIA:
            - All vehicles reach destination
            - No casualties

            SUGGESTED IMPROVEMENTS:
            - Clarify route alternatives

            CONFIDENCE: HIGH
            """)
        let scribe = ScribeAgent(llmClient: client)

        let input = AgentInput(missionStatement: "Do convoy escort")
        let context = MissionContext(intent: "Secure convoy", endState: "Delivered")

        let output = try await scribe.run(input: input, context: context, doctrine: [])

        XCTAssertTrue(output.requiresApproval)  // Scribe requires Gate A approval
        XCTAssertFalse(output.summary.isEmpty)
    }

    func testCoordinatorAgentCreation() {
        let client = MockLLMClient()
        let coordinator = CoordinatorAgent(llmClient: client)

        XCTAssertEqual(coordinator.id, "coordinator")
        XCTAssertEqual(coordinator.mcppPhase, "problem_framing")
    }

    func testIntegratorAgentCreation() {
        let client = MockLLMClient()
        let integrator = IntegratorAgent(llmClient: client)

        XCTAssertEqual(integrator.id, "integrator")
        XCTAssertEqual(integrator.mcppPhase, "coa_dev")
    }

    func testIntegratorAgentWithAssessments() async throws {
        let client = MockLLMClient(response: """
            INTEGRATED ASSESSMENT:
            Combined analysis from all sections.

            CONFLICTS IDENTIFIED:
            - S3 and S4 have conflicting timelines

            CONFIDENCE: MEDIUM
            """)
        let integrator = IntegratorAgent(llmClient: client)

        let assessments = [
            SpecialistAssessment(agentId: "s3", shop: "S3", summary: "Ops assessment", confidence: 0.8),
            SpecialistAssessment(agentId: "s4", shop: "S4", summary: "Log assessment", confidence: 0.7)
        ]
        let input = AgentInput(missionStatement: "Test", specialistAssessments: assessments)
        let context = MissionContext()

        let output = try await integrator.run(input: input, context: context, doctrine: [])

        XCTAssertFalse(output.summary.isEmpty)
    }

    func testEvaluatorAgentCreation() {
        let client = MockLLMClient()
        let evaluator = EvaluatorAgent(llmClient: client)

        XCTAssertEqual(evaluator.id, "evaluator")
        XCTAssertEqual(evaluator.mcppPhase, "coa_dev")
    }

    func testTaskingAgentCreation() {
        let client = MockLLMClient()
        let tasking = TaskingAgent(llmClient: client)

        XCTAssertEqual(tasking.id, "tasking")
        XCTAssertEqual(tasking.mcppPhase, "orders")
    }

    func testTaskingAgentRun() async throws {
        let client = MockLLMClient(response: """
            EXECUTION TIMELINE:

            PHASE 1: Preparation
            Task 1.1: Assemble convoy
            - Assigned to: S4

            CONFIDENCE: HIGH
            """)
        let tasking = TaskingAgent(llmClient: client)

        let input = AgentInput(missionStatement: "Convoy operation")
        let context = MissionContext()

        let output = try await tasking.run(input: input, context: context, doctrine: [])

        XCTAssertTrue(output.requiresApproval)  // Tasking requires Gate D approval
    }

    // MARK: - Specialist Agent Tests

    func testSpecialistAgentCreation() {
        let client = MockLLMClient()
        let specialist = SpecialistAgent(
            shop: "G3",
            mos: "0302",
            name: "G3 Ops Specialist",
            llmClient: client
        )

        XCTAssertEqual(specialist.shop, "G3")
        XCTAssertEqual(specialist.mosCode, "0302")
        XCTAssertEqual(specialist.mcppPhase, "coa_dev")
    }

    func testSpecialistAgentRun() async throws {
        let client = MockLLMClient(response: """
            ASSESSMENT:
            Operations analysis complete.

            RECOMMENDATIONS:
            - Recommend phased approach

            RISKS:
            - Risk 1: Timeline pressure - Likelihood M, Impact H

            CONFIDENCE: HIGH
            """)
        let specialist = SpecialistAgent(
            shop: "G3",
            mos: "0302",
            name: "G3 Ops",
            llmClient: client
        )

        let input = AgentInput(missionStatement: "Test ops")
        let context = MissionContext()

        let output = try await specialist.run(input: input, context: context, doctrine: [])

        XCTAssertFalse(output.summary.isEmpty)
        XCTAssertGreaterThan(output.recommendations.count, 0)
    }

    // MARK: - Specialist Factory Tests

    func testSpecialistAgentFactory() {
        let client = MockLLMClient()
        let factory = SpecialistAgentFactory(llmClient: client)

        let g1 = factory.createG1Agent()
        XCTAssertEqual(g1.shop, "G1")

        let g2 = factory.createG2Agent()
        XCTAssertEqual(g2.shop, "G2")

        let g3 = factory.createG3Agent()
        XCTAssertEqual(g3.shop, "G3")

        let g4 = factory.createG4Agent()
        XCTAssertEqual(g4.shop, "G4")

        let g5 = factory.createG5Agent()
        XCTAssertEqual(g5.shop, "G5")

        let g6 = factory.createG6Agent()
        XCTAssertEqual(g6.shop, "G6")

        let g7 = factory.createG7Agent()
        XCTAssertEqual(g7.shop, "G7")

        let g8 = factory.createG8Agent()
        XCTAssertEqual(g8.shop, "G8")

        let g9 = factory.createG9Agent()
        XCTAssertEqual(g9.shop, "G9")
    }

    func testSpecialistFactoryCreateAll() {
        let client = MockLLMClient()
        let factory = SpecialistAgentFactory(llmClient: client)

        let all = factory.createAllSpecialists()
        XCTAssertEqual(all.count, 9)

        let shops = Set(all.compactMap(\.shop))
        XCTAssertTrue(shops.contains("G1"))
        XCTAssertTrue(shops.contains("G9"))
    }

    func testSpecialistFactoryCreateByShop() {
        let client = MockLLMClient()
        let factory = SpecialistAgentFactory(llmClient: client)

        let s3 = factory.createSpecialist(for: "S3")
        XCTAssertNotNil(s3)
        XCTAssertEqual(s3?.shop, "G3")  // S3 maps to G3 agent

        let unknown = factory.createSpecialist(for: "XYZ")
        XCTAssertNil(unknown)
    }

    // MARK: - Agent Factory Tests

    func testAgentFactory() {
        let client = MockLLMClient()
        let factory = AgentFactory(llmClient: client)

        let scribe = factory.createScribe()
        XCTAssertEqual(scribe.id, "scribe")

        let coordinator = factory.createCoordinator()
        XCTAssertEqual(coordinator.id, "coordinator")

        let integrator = factory.createIntegrator()
        XCTAssertEqual(integrator.id, "integrator")

        let evaluator = factory.createEvaluator()
        XCTAssertEqual(evaluator.id, "evaluator")

        let tasking = factory.createTasking()
        XCTAssertEqual(tasking.id, "tasking")
    }

    // MARK: - Prompt Template Tests

    func testPromptTemplateRendering() {
        let template = PromptTemplate(template: "Hello {{name}}, your mission is {{mission}}.")

        let rendered = template.render(with: [
            "name": "Commander",
            "mission": "secure the area"
        ])

        XCTAssertEqual(rendered, "Hello Commander, your mission is secure the area.")
    }

    func testPromptTemplateVariableExtraction() {
        let template = PromptTemplate(template: "{{a}} and {{b}} and {{a}} again")

        XCTAssertEqual(template.variables, ["a", "b"])
    }

    func testMissionContextBuilder() {
        let context = MissionContext(
            intent: "Secure the convoy",
            endState: "All vehicles delivered",
            constraints: ["Limited time", "No air support"],
            acceptanceCriteria: ["Zero casualties"]
        )

        let rendered = PromptBuilder.buildMissionContext(context, statement: "Escort convoy")

        XCTAssertTrue(rendered.contains("Escort convoy"))
        XCTAssertTrue(rendered.contains("Secure the convoy"))
        XCTAssertTrue(rendered.contains("Limited time"))
    }

    func testDataSnapshotBuilder() {
        let snapshots = DataSnapshots(
            readiness: ReadinessSnapshot(
                unitId: "test",
                personnelReadiness: 0.85,
                equipmentReadiness: 0.80,
                trainingReadiness: 0.90,
                overallReadiness: 0.85,
                drrsCategory: "C2"
            ),
            funds: FundsSnapshot(
                unitId: "test",
                fiscalYear: 2026,
                authorizedAmount: 1_000_000,
                obligatedAmount: 500_000,
                expendedAmount: 400_000,
                remainingAmount: 500_000,
                commitmentRate: 0.5
            ),
            maintenance: MaintenanceSnapshot(
                unitId: "test",
                totalEquipment: 100,
                missionCapable: 85,
                inMaintenance: 10,
                awaitingParts: 3,
                deadlined: 2,
                mcRate: 0.85
            )
        )

        let rendered = PromptBuilder.buildDataSnapshot(snapshots)

        XCTAssertTrue(rendered.contains("85%"))
        XCTAssertTrue(rendered.contains("C2"))
        XCTAssertTrue(rendered.contains("2026"))
    }

    // MARK: - Agent Registry Tests

    func testAgentRegistry() async {
        let registry = AgentRegistry()
        let client = MockLLMClient()

        let scribe = ScribeAgent(llmClient: client)
        let g3 = SpecialistAgent(shop: "G3", mos: "0302", name: "G3", llmClient: client)

        await registry.register(scribe)
        await registry.register(g3)

        let allAgents = await registry.all()
        XCTAssertEqual(allAgents.count, 2)

        let foundScribe = await registry.get(id: "scribe")
        XCTAssertNotNil(foundScribe)

        let g3Agents = await registry.byShop("G3")
        XCTAssertEqual(g3Agents.count, 1)
    }
}
