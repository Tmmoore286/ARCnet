import Foundation
import ARCnetDomain
import ARCnetLLM
import ARCnetAgents
import ARCnetData

// MARK: - Pipeline Orchestrator
// Orchestrates the full MCPP-aligned decision support pipeline.
// Integrates agent selection, specialist execution, COA tournament, and gate enforcement.

public actor PipelineOrchestrator {
    private let agentSelector: any AgentSelector
    private let specialistFactory: SpecialistAgentFactory
    private let coaTournament: COATournament
    private let gateEnforcer: GateEnforcer
    private let dataGateway: any DataGateway
    private let orgRepository: any OrgRepository

    // Stage agents
    private let scribeAgent: ScribeAgent
    private let coordinatorAgent: CoordinatorAgent
    private let integratorAgent: IntegratorAgent
    private let evaluatorAgent: EvaluatorAgent
    private let taskingAgent: TaskingAgent

    public init(
        llmClient: LLMClient,
        embeddingClient: EmbeddingClient,
        orgRepository: any OrgRepository,
        doctrineRepository: any DoctrineRepository,
        dataGateway: any DataGateway,
        gatePolicyRepository: any GatePolicyRepository,
        config: PipelineConfig = PipelineConfig()
    ) {
        self.orgRepository = orgRepository
        self.dataGateway = dataGateway

        // Initialize embedding service for agent selection
        let embeddingService = EmbeddingService(
            client: embeddingClient,
            doctrineRepository: doctrineRepository,
            config: config.embeddingConfig
        )

        // Initialize agent selector
        self.agentSelector = DefaultAgentSelector(embeddingService: embeddingService)

        // Initialize specialist factory
        self.specialistFactory = SpecialistAgentFactory(
            llmClient: llmClient,
            config: config.llmConfig
        )

        // Initialize COA tournament
        if config.useDeterministicCOA {
            self.coaTournament = COATournamentFactory.createDeterministicTournament()
        } else if config.useWargaming {
            self.coaTournament = COATournamentFactory.createWargamingTournament(llmClient: llmClient)
        } else {
            self.coaTournament = COATournamentFactory.createStandardTournament(llmClient: llmClient)
        }

        // Initialize gate enforcer
        self.gateEnforcer = GateEnforcer(policyRepository: gatePolicyRepository)

        // Initialize stage agents
        let agentFactory = AgentFactory(llmClient: llmClient, config: config.llmConfig)
        self.scribeAgent = agentFactory.createScribe()
        self.coordinatorAgent = agentFactory.createCoordinator()
        self.integratorAgent = agentFactory.createIntegrator()
        self.evaluatorAgent = agentFactory.createEvaluator()
        self.taskingAgent = agentFactory.createTasking()
    }

    // MARK: - Main Pipeline Execution

    /// Execute the full decision support pipeline for a mission
    public func executePipeline(
        mission: MissionRun,
        orgUnitId: String,
        autonomyMode: AutonomyMode = .hitl
    ) -> AsyncStream<PipelineEvent> {
        AsyncStream { continuation in
            Task {
                do {
                    try await runPipeline(
                        mission: mission,
                        orgUnitId: orgUnitId,
                        autonomyMode: autonomyMode,
                        continuation: continuation
                    )
                } catch {
                    continuation.yield(.error(PipelineError.executionFailed(error.localizedDescription)))
                }
                continuation.finish()
            }
        }
    }

    private func runPipeline(
        mission: MissionRun,
        orgUnitId: String,
        autonomyMode: AutonomyMode,
        continuation: AsyncStream<PipelineEvent>.Continuation
    ) async throws {
        var checkpoints: [Checkpoint] = []
        let startTime = Date()

        // Build mission context
        let context = MissionContext(
            intent: mission.missionStatement,
            endState: mission.endState,
            constraints: mission.constraints,
            acceptanceCriteria: mission.acceptanceCriteria
        )

        // Fetch org unit
        guard let orgUnit = try await orgRepository.loadUnit(id: orgUnitId) else {
            throw PipelineError.invalidConfiguration("Org unit \(orgUnitId) not found")
        }

        // Fetch data snapshots
        let snapshots = await fetchDataSnapshots(unitId: orgUnitId)

        // Build doctrine snippets (empty for now - could be enhanced with embedding search)
        let doctrine: [DoctrineSnippet] = []

        // PHASE 1: Problem Framing (Gate A)
        continuation.yield(.phaseStarted("problem_framing", "Gate A"))

        // 1a. Scribe: Transform mission input
        let scribeInput = AgentInput(
            missionStatement: mission.missionStatement,
            dataSnapshots: snapshots
        )
        let scribeOutput = try await scribeAgent.run(
            input: scribeInput,
            context: context,
            doctrine: doctrine
        )

        let scribeCheckpoint = Checkpoint(
            stage: "Scribe",
            agent: scribeAgent.id,
            summary: scribeOutput.summary,
            confidence: scribeOutput.confidence,
            requiresApproval: scribeOutput.requiresApproval,
            mcppPhase: "problem_framing",
            gate: "A"
        )
        checkpoints.append(scribeCheckpoint)
        continuation.yield(.checkpoint(scribeCheckpoint))

        // Gate A enforcement
        let gateAResult = try await gateEnforcer.enforceGate(
            "A",
            checkpoint: scribeCheckpoint,
            autonomyMode: autonomyMode
        )
        if gateAResult.requiresPause && autonomyMode == .hitl {
            continuation.yield(.gateReached("A", gateAResult))
        }

        // 1b. Coordinator: Route to specialists
        let coordinatorInput = AgentInput(
            missionStatement: mission.missionStatement,
            priorCheckpoints: checkpoints,
            dataSnapshots: snapshots
        )
        let coordinatorOutput = try await coordinatorAgent.run(
            input: coordinatorInput,
            context: context,
            doctrine: doctrine
        )

        let coordinatorCheckpoint = Checkpoint(
            stage: "Coordinator",
            agent: coordinatorAgent.id,
            summary: coordinatorOutput.summary,
            confidence: coordinatorOutput.confidence,
            mcppPhase: "problem_framing",
            gate: "A"
        )
        checkpoints.append(coordinatorCheckpoint)
        continuation.yield(.checkpoint(coordinatorCheckpoint))

        // PHASE 2: Specialist Analysis
        continuation.yield(.phaseStarted("specialist_analysis", "Pre-Gate B"))

        // Select specialists based on flow mode
        let flowMode = parseFlowMode(from: coordinatorOutput.summary)
        let selectedAgents = try await agentSelector.select(
            mission: context,
            orgUnit: orgUnit,
            mode: flowMode
        )
        continuation.yield(.agentsSelected(selectedAgents, flowMode))

        // Run specialist agents in parallel
        var specialistAssessments: [SpecialistAssessment] = []
        let currentCheckpoints = checkpoints  // Capture immutable copy for concurrent access
        await withTaskGroup(of: SpecialistAssessment?.self) { group in
            for candidate in selectedAgents {
                guard let shop = candidate.shop else { continue }
                guard let specialist = specialistFactory.createSpecialist(for: shop) else { continue }

                group.addTask {
                    do {
                        let input = AgentInput(
                            missionStatement: mission.missionStatement,
                            priorCheckpoints: currentCheckpoints,
                            dataSnapshots: snapshots
                        )
                        let output = try await specialist.run(
                            input: input,
                            context: context,
                            doctrine: doctrine
                        )
                        return SpecialistAssessment(
                            agentId: specialist.id,
                            shop: shop,
                            summary: output.summary,
                            confidence: output.confidence,
                            evidence: output.evidence,
                            recommendations: output.recommendations
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await assessment in group {
                if let assessment = assessment {
                    specialistAssessments.append(assessment)
                    continuation.yield(.specialistCompleted(assessment))
                }
            }
        }

        // PHASE 3: Integration (Gate B)
        continuation.yield(.phaseStarted("coa_dev", "Gate B"))

        // 3a. Integrator: Merge specialist assessments
        let integratorInput = AgentInput(
            missionStatement: mission.missionStatement,
            priorCheckpoints: checkpoints,
            specialistAssessments: specialistAssessments,
            dataSnapshots: snapshots
        )
        let integratorOutput = try await integratorAgent.run(
            input: integratorInput,
            context: context,
            doctrine: doctrine
        )

        let integratorCheckpoint = Checkpoint(
            stage: "Integrator",
            agent: integratorAgent.id,
            summary: integratorOutput.summary,
            confidence: integratorOutput.confidence,
            mcppPhase: "coa_dev",
            gate: "B"
        )
        checkpoints.append(integratorCheckpoint)
        continuation.yield(.checkpoint(integratorCheckpoint))

        // 3b. Evaluator: Determine if COA tournament needed
        let evaluatorInput = AgentInput(
            missionStatement: mission.missionStatement,
            priorCheckpoints: checkpoints,
            specialistAssessments: specialistAssessments,
            dataSnapshots: snapshots
        )
        let evaluatorOutput = try await evaluatorAgent.run(
            input: evaluatorInput,
            context: context,
            doctrine: doctrine
        )

        let evaluatorCheckpoint = Checkpoint(
            stage: "Evaluator",
            agent: evaluatorAgent.id,
            summary: evaluatorOutput.summary,
            confidence: evaluatorOutput.confidence,
            mcppPhase: "coa_dev",
            gate: "B"
        )
        checkpoints.append(evaluatorCheckpoint)
        continuation.yield(.checkpoint(evaluatorCheckpoint))

        // Gate B enforcement
        let gateBResult = try await gateEnforcer.enforceGate(
            "B",
            checkpoint: integratorCheckpoint,
            autonomyMode: autonomyMode
        )
        if gateBResult.requiresPause && autonomyMode == .hitl {
            continuation.yield(.gateReached("B", gateBResult))
        }

        // PHASE 4: COA Tournament (Gate C)
        let requiresTournament = evaluatorOutput.summary.uppercased().contains("YES") ||
                                 evaluatorOutput.summary.uppercased().contains("TOURNAMENT REQUIRED")

        var selectedCOA: CourseOfAction?
        var tournamentResult: TournamentResult?

        if requiresTournament {
            continuation.yield(.phaseStarted("comparison", "Gate C"))

            // Build integrated assessment for COA generation
            let integratedAssessment = buildIntegratedAssessment(
                missionStatement: mission.missionStatement,
                specialistAssessments: specialistAssessments,
                integratorOutput: integratorOutput
            )

            // Run COA tournament
            let tournamentConfig = TournamentConfig(
                coaCount: 3,
                rubric: ScoringRubric(),
                requireWargame: true,
                minScoreDifferential: 0.5
            )

            tournamentResult = try await coaTournament.runTournament(
                assessment: integratedAssessment,
                context: context,
                config: tournamentConfig
            )
            selectedCOA = tournamentResult?.selectedCOA

            let tournamentCheckpoint = Checkpoint(
                stage: "COA Tournament",
                agent: "tournament",
                summary: "Tournament completed. Recommended: \(selectedCOA?.name ?? "Unknown"). Score: \(String(format: "%.1f", tournamentResult?.ranking.rankedCOAs.first?.score ?? 0))",
                confidence: selectedCOA != nil ? 0.8 : 0.5,
                requiresApproval: tournamentResult?.requiresCommanderDecision ?? true,
                mcppPhase: "comparison",
                gate: "C"
            )
            checkpoints.append(tournamentCheckpoint)
            continuation.yield(.checkpoint(tournamentCheckpoint))
            continuation.yield(.tournamentCompleted(tournamentResult!))

            // Gate C enforcement
            let gateCResult = try await gateEnforcer.enforceGate(
                "C",
                checkpoint: tournamentCheckpoint,
                autonomyMode: autonomyMode
            )
            if gateCResult.requiresPause && autonomyMode == .hitl {
                continuation.yield(.gateReached("C", gateCResult))
            }
        } else {
            // Single COA path - create default COA from integrated assessment
            selectedCOA = CourseOfAction(
                name: "Direct Execution",
                description: "Execute mission as planned based on staff assessment",
                readinessImpact: 0.05,
                fundingRequired: 50000,
                scheduleImpactDays: 14
            )
        }

        // PHASE 5: Tasking (Gate D)
        continuation.yield(.phaseStarted("orders", "Gate D"))

        let taskingInput = AgentInput(
            missionStatement: mission.missionStatement,
            priorCheckpoints: checkpoints,
            specialistAssessments: specialistAssessments,
            dataSnapshots: snapshots
        )
        let taskingOutput = try await taskingAgent.run(
            input: taskingInput,
            context: context,
            doctrine: doctrine
        )

        let taskingCheckpoint = Checkpoint(
            stage: "Tasking",
            agent: taskingAgent.id,
            summary: taskingOutput.summary,
            confidence: taskingOutput.confidence,
            requiresApproval: true,
            mcppPhase: "orders",
            gate: "D"
        )
        checkpoints.append(taskingCheckpoint)
        continuation.yield(.checkpoint(taskingCheckpoint))

        // Gate D enforcement
        let gateDResult = try await gateEnforcer.enforceGate(
            "D",
            checkpoint: taskingCheckpoint,
            autonomyMode: autonomyMode
        )
        if gateDResult.requiresPause && autonomyMode == .hitl {
            continuation.yield(.gateReached("D", gateDResult))
        }

        // Pipeline complete
        let duration = Date().timeIntervalSince(startTime)
        let result = PipelineResult(
            missionId: mission.id,
            checkpoints: checkpoints,
            selectedCOA: selectedCOA,
            tournamentResult: tournamentResult,
            specialistAssessments: specialistAssessments,
            duration: duration,
            completedAt: Date()
        )
        continuation.yield(.completed(result))
    }

    // MARK: - Helper Methods

    private func fetchDataSnapshots(unitId: String) async -> DataSnapshots {
        let readiness = await dataGateway.readiness(for: unitId)
        let funds = await dataGateway.funds(for: unitId)
        let maintenance = await dataGateway.maintenance(for: unitId)
        return DataSnapshots(readiness: readiness, funds: funds, maintenance: maintenance)
    }

    private func parseFlowMode(from text: String) -> FlowMode {
        let upper = text.uppercased()
        if upper.contains("MESH") {
            return .mesh
        } else if upper.contains("HYBRID") {
            return .hybrid
        }
        return .org
    }

    private func buildIntegratedAssessment(
        missionStatement: String,
        specialistAssessments: [SpecialistAssessment],
        integratorOutput: AgentOutput
    ) -> IntegratedAssessment {
        // Parse resource impacts from integrator output
        let resourceImpacts = parseResourceImpacts(from: integratorOutput.summary)

        // Parse conflicts
        let conflicts = integratorOutput.conflicts.enumerated().map { _, desc in
            ConflictItem(
                shopA: "Shop",
                shopB: "Shop",
                description: desc,
                severity: .medium
            )
        }

        return IntegratedAssessment(
            missionStatement: missionStatement,
            specialistAssessments: specialistAssessments,
            conflicts: conflicts,
            resourceImpacts: resourceImpacts,
            recommendations: integratorOutput.recommendations
        )
    }

    private func parseResourceImpacts(from text: String) -> ResourceImpacts {
        var personnel = 0.0
        var equipment = 0.0
        var funds = 0.0
        var schedule = 0

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("personnel") {
                if let pct = extractPercentage(from: line) {
                    personnel = pct
                }
            } else if lower.contains("equipment") {
                if let pct = extractPercentage(from: line) {
                    equipment = pct
                }
            } else if lower.contains("fund") {
                if let amount = extractAmount(from: line) {
                    funds = amount
                }
            } else if lower.contains("schedule") || lower.contains("day") {
                if let days = extractDays(from: line) {
                    schedule = days
                }
            }
        }

        return ResourceImpacts(
            personnel: personnel,
            equipment: equipment,
            funds: funds,
            schedule: schedule
        )
    }

    private func extractPercentage(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }

    private func extractAmount(from text: String) -> Double? {
        let pattern = #"\$?\s*(\d[\d,]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let valueStr = text[range].replacingOccurrences(of: ",", with: "")
        return Double(valueStr)
    }

    private func extractDays(from text: String) -> Int? {
        let pattern = #"(\d+)\s*days?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[range])
    }
}

// MARK: - Pipeline Configuration

public struct PipelineConfig: Sendable {
    public var llmConfig: LLMConfig
    public var embeddingConfig: EmbeddingConfig
    public var useDeterministicCOA: Bool
    public var useWargaming: Bool
    public var maxSpecialists: Int
    public var parallelSpecialists: Bool

    public init(
        llmConfig: LLMConfig = LLMConfig(),
        embeddingConfig: EmbeddingConfig = .small,
        useDeterministicCOA: Bool = false,
        useWargaming: Bool = true,
        maxSpecialists: Int = 9,
        parallelSpecialists: Bool = true
    ) {
        self.llmConfig = llmConfig
        self.embeddingConfig = embeddingConfig
        self.useDeterministicCOA = useDeterministicCOA
        self.useWargaming = useWargaming
        self.maxSpecialists = maxSpecialists
        self.parallelSpecialists = parallelSpecialists
    }
}

// MARK: - Pipeline Events

public enum PipelineEvent: Sendable {
    case phaseStarted(String, String)  // phase, gate
    case checkpoint(Checkpoint)
    case agentsSelected([AgentCandidate], FlowMode)
    case specialistCompleted(SpecialistAssessment)
    case tournamentCompleted(TournamentResult)
    case gateReached(String, GateResult)
    case completed(PipelineResult)
    case error(PipelineError)
}

// MARK: - Pipeline Result

public struct PipelineResult: Sendable {
    public let missionId: UUID
    public let checkpoints: [Checkpoint]
    public let selectedCOA: CourseOfAction?
    public let tournamentResult: TournamentResult?
    public let specialistAssessments: [SpecialistAssessment]
    public let duration: TimeInterval
    public let completedAt: Date

    public init(
        missionId: UUID,
        checkpoints: [Checkpoint],
        selectedCOA: CourseOfAction?,
        tournamentResult: TournamentResult?,
        specialistAssessments: [SpecialistAssessment],
        duration: TimeInterval,
        completedAt: Date
    ) {
        self.missionId = missionId
        self.checkpoints = checkpoints
        self.selectedCOA = selectedCOA
        self.tournamentResult = tournamentResult
        self.specialistAssessments = specialistAssessments
        self.duration = duration
        self.completedAt = completedAt
    }
}

// MARK: - Pipeline Errors

public enum PipelineError: Error, Sendable {
    case executionFailed(String)
    case gateRejected(String)
    case agentFailed(String, String)
    case tournamentFailed(String)
    case invalidConfiguration(String)
}
