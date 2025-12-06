import Foundation
import ARCnetDomain
import ARCnetData
import ARCnetLLM

// MARK: - Agent Selector Protocol
// Selects agents based on flow mode (Org, Mesh, Hybrid).

public protocol AgentSelector: Sendable {
    /// Select agents for a mission
    func select(
        mission: MissionContext,
        orgUnit: OrgUnit,
        mode: FlowMode
    ) async throws -> [AgentCandidate]
}

// MARK: - Default Agent Selector Implementation

public actor DefaultAgentSelector: AgentSelector {
    private let embeddingService: EmbeddingService
    private let orgModeSelector: OrgModeSelector
    private let meshModeSelector: MeshModeSelector
    private let hybridModeSelector: HybridModeSelector

    public init(embeddingService: EmbeddingService) {
        self.embeddingService = embeddingService
        self.orgModeSelector = OrgModeSelector()
        self.meshModeSelector = MeshModeSelector(embeddingService: embeddingService)
        self.hybridModeSelector = HybridModeSelector(
            orgSelector: OrgModeSelector(),
            meshSelector: MeshModeSelector(embeddingService: embeddingService)
        )
    }

    public func select(
        mission: MissionContext,
        orgUnit: OrgUnit,
        mode: FlowMode
    ) async throws -> [AgentCandidate] {
        switch mode {
        case .org:
            return try await orgModeSelector.select(mission: mission, orgUnit: orgUnit)
        case .mesh:
            return try await meshModeSelector.select(mission: mission, orgUnit: orgUnit)
        case .hybrid:
            return try await hybridModeSelector.select(mission: mission, orgUnit: orgUnit)
        }
    }
}

// MARK: - Org Mode Selector
// Deterministic staff-lane routing based on org structure.

public struct OrgModeSelector: Sendable {
    private let weights: SelectionWeights
    private let caps: SelectionCaps
    private let requiredShops: Set<String>

    public init(
        weights: SelectionWeights = .orgDefaults,
        caps: SelectionCaps = SelectionCaps(),
        requiredShops: Set<String> = ["S2", "S3", "S4", "S6"]
    ) {
        self.weights = weights
        self.caps = caps
        self.requiredShops = requiredShops
    }

    public func select(
        mission: MissionContext,
        orgUnit: OrgUnit
    ) async throws -> [AgentCandidate] {
        let billets = orgUnit.nodes.filter { $0.type == .billet }

        // Group by shop
        var shopBillets: [String: [OrgNode]] = [:]
        for billet in billets {
            if let shop = billet.shop {
                shopBillets[shop, default: []].append(billet)
            }
        }

        // Select from each required shop
        var selected: [AgentCandidate] = []
        var coveredShops: Set<String> = []

        let calculator = CompositeScoreCalculator(weights: weights)
        let chainScorer = ChainOfCommandScorer()
        let coverageScorer = CoverageScorer(requiredShops: requiredShops)
        let availabilityScorer = AvailabilityScorer()
        let loadScorer = LoadScorer()

        // First pass: required shops
        for shop in requiredShops {
            guard let candidates = shopBillets[shop], !candidates.isEmpty else { continue }

            // Take up to perShop limit from each required shop
            let toSelect = min(caps.perShop, candidates.count)

            for i in 0..<toSelect {
                let node = candidates[i]
                var candidate = AgentCandidate(
                    nodeId: node.id,
                    name: node.name,
                    shop: node.shop,
                    mos: node.mos
                )

                // Calculate scores (similarity is less important in org mode)
                candidate.similarityScore = 0.5  // Default for org mode
                candidate.chainScore = chainScorer.score(
                    node: node,
                    missionShops: requiredShops,
                    orgTree: orgUnit
                )
                candidate.coverageScore = coverageScorer.score(node: node, alreadyCovered: coveredShops)
                candidate.availabilityScore = availabilityScorer.score(node: node)
                candidate.loadScore = loadScorer.score(agentId: node.id)

                candidate.compositeScore = calculator.calculate(
                    similarityScore: candidate.similarityScore,
                    chainScore: candidate.chainScore,
                    coverageScore: candidate.coverageScore,
                    availabilityScore: candidate.availabilityScore,
                    loadScore: candidate.loadScore
                )

                selected.append(candidate)
            }

            coveredShops.insert(shop)
        }

        // Sort by composite score
        selected.sort { $0.compositeScore > $1.compositeScore }

        // Apply total cap
        return Array(selected.prefix(caps.totalAgents))
    }
}

// MARK: - Mesh Mode Selector
// Similarity-gated expert activation with diversity penalty.

public actor MeshModeSelector {
    private let embeddingService: EmbeddingService
    private let weights: SelectionWeights
    private let caps: SelectionCaps
    private let similarityThreshold: Float
    private let diversityPenalty: Float  // λ in the formula
    private let mustIncludeShops: Set<String>

    public init(
        embeddingService: EmbeddingService,
        weights: SelectionWeights = .meshDefaults,
        caps: SelectionCaps = SelectionCaps(),
        similarityThreshold: Float = 0.3,
        diversityPenalty: Float = 0.1,
        mustIncludeShops: Set<String> = ["S3", "S4"]
    ) {
        self.embeddingService = embeddingService
        self.weights = weights
        self.caps = caps
        self.similarityThreshold = similarityThreshold
        self.diversityPenalty = diversityPenalty
        self.mustIncludeShops = mustIncludeShops
    }

    public func select(
        mission: MissionContext,
        orgUnit: OrgUnit
    ) async throws -> [AgentCandidate] {
        let billets = orgUnit.nodes.filter { $0.type == .billet }

        // Get mission embedding
        let missionText = "\(mission.intent) \(mission.endState)"
        let missionVector = try await embeddingService.embedMission(missionText)

        // Calculate scores for all candidates
        let calculator = CompositeScoreCalculator(weights: weights)
        let chainScorer = ChainOfCommandScorer()
        let availabilityScorer = AvailabilityScorer()
        let loadScorer = LoadScorer()

        var candidates: [(candidate: AgentCandidate, vector: [Float])] = []

        for billet in billets {
            let agentVector = try await embeddingService.embedAgent(node: billet)
            let similarity = VectorMath.cosineSimilarity(missionVector, agentVector)

            // Filter by similarity threshold
            guard similarity >= similarityThreshold else { continue }

            var candidate = AgentCandidate(
                nodeId: billet.id,
                name: billet.name,
                shop: billet.shop,
                mos: billet.mos,
                similarityScore: similarity
            )

            candidate.chainScore = chainScorer.score(
                node: billet,
                missionShops: mustIncludeShops,
                orgTree: orgUnit
            )
            candidate.availabilityScore = availabilityScorer.score(node: billet)
            candidate.loadScore = loadScorer.score(agentId: billet.id)

            candidate.compositeScore = calculator.calculate(
                similarityScore: candidate.similarityScore,
                chainScore: candidate.chainScore,
                coverageScore: 0.5,  // Initial coverage score
                availabilityScore: candidate.availabilityScore,
                loadScore: candidate.loadScore
            )

            candidates.append((candidate, agentVector))
        }

        // Greedy selection with diversity penalty
        return greedySelectWithDiversity(
            candidates: candidates,
            mustInclude: mustIncludeShops,
            maxTotal: caps.totalAgents,
            maxPerShop: caps.perShop
        )
    }

    /// Greedy selection algorithm that penalizes redundancy
    /// Implements: A_mesh = M ∪ argmax[Σ S(i) - λ Σ cos(vi, vj)]
    private func greedySelectWithDiversity(
        candidates: [(candidate: AgentCandidate, vector: [Float])],
        mustInclude: Set<String>,
        maxTotal: Int,
        maxPerShop: Int
    ) -> [AgentCandidate] {
        var selected: [AgentCandidate] = []
        var selectedVectors: [[Float]] = []
        var shopCounts: [String: Int] = [:]
        var remainingCandidates = candidates

        // First: add must-include shops
        for shop in mustInclude {
            let shopCandidates = remainingCandidates.filter { $0.candidate.shop == shop }
            if let best = shopCandidates.max(by: { $0.candidate.compositeScore < $1.candidate.compositeScore }) {
                selected.append(best.candidate)
                selectedVectors.append(best.vector)
                shopCounts[shop, default: 0] += 1
                remainingCandidates.removeAll { $0.candidate.id == best.candidate.id }
            }
        }

        // Greedy selection for remaining slots
        while selected.count < maxTotal && !remainingCandidates.isEmpty {
            var bestIndex: Int?
            var bestMarginalGain: Float = -.infinity

            for (index, item) in remainingCandidates.enumerated() {
                let (candidate, vector) = item

                // Check shop cap
                if let shop = candidate.shop, (shopCounts[shop] ?? 0) >= maxPerShop {
                    continue
                }

                // Calculate marginal gain: S(i) - λ * redundancy
                let redundancy = VectorMath.marginalRedundancy(
                    newVector: vector,
                    existingVectors: selectedVectors
                )
                let marginalGain = candidate.compositeScore - diversityPenalty * redundancy

                if marginalGain > bestMarginalGain {
                    bestMarginalGain = marginalGain
                    bestIndex = index
                }
            }

            guard let index = bestIndex else { break }

            let (candidate, vector) = remainingCandidates[index]
            selected.append(candidate)
            selectedVectors.append(vector)

            if let shop = candidate.shop {
                shopCounts[shop, default: 0] += 1
            }

            remainingCandidates.remove(at: index)
        }

        return selected
    }
}

// MARK: - Hybrid Mode Selector
// Uses Org for status retrieval, Mesh for planning.

public actor HybridModeSelector {
    private let orgSelector: OrgModeSelector
    private let meshSelector: MeshModeSelector
    private let caps: SelectionCaps

    public init(
        orgSelector: OrgModeSelector,
        meshSelector: MeshModeSelector,
        caps: SelectionCaps = SelectionCaps()
    ) {
        self.orgSelector = orgSelector
        self.meshSelector = meshSelector
        self.caps = caps
    }

    public func select(
        mission: MissionContext,
        orgUnit: OrgUnit
    ) async throws -> [AgentCandidate] {
        // Get org-lane agents for status retrieval
        let orgAgents = try await orgSelector.select(mission: mission, orgUnit: orgUnit)

        // Calculate remaining capacity
        let remainingCapacity = caps.totalAgents - orgAgents.count
        guard remainingCapacity > 0 else {
            return orgAgents
        }

        // Get mesh agents excluding org-selected ones
        let orgIds = Set(orgAgents.map(\.nodeId))
        var meshAgents = try await meshSelector.select(mission: mission, orgUnit: orgUnit)
        meshAgents.removeAll { orgIds.contains($0.nodeId) }

        // Combine: org agents + top mesh agents within remaining capacity
        let additionalMesh = Array(meshAgents.prefix(remainingCapacity))

        return orgAgents + additionalMesh
    }
}

// MARK: - Flow Advisor
// Recommends flow mode based on mission analysis.

public struct FlowAdvisor: Sendable {
    private let complexityThreshold: Int
    private let crossFunctionalKeywords: Set<String>

    public init(
        complexityThreshold: Int = 3,
        crossFunctionalKeywords: Set<String> = [
            "coordinate", "synchronize", "integrate", "joint", "combined",
            "multi", "cross-functional", "enterprise", "comprehensive"
        ]
    ) {
        self.complexityThreshold = complexityThreshold
        self.crossFunctionalKeywords = crossFunctionalKeywords
    }

    /// Recommend flow mode based on mission context
    public func recommend(mission: MissionContext) -> FlowModeRecommendation {
        let missionText = "\(mission.intent) \(mission.endState) \(mission.constraints.joined(separator: " "))"
        let lowercased = missionText.lowercased()

        // Check for cross-functional indicators
        let crossFunctionalScore = crossFunctionalKeywords.filter { lowercased.contains($0) }.count

        // Check constraint complexity
        let constraintComplexity = mission.constraints.count

        // Determine recommendation
        if crossFunctionalScore >= 2 || constraintComplexity >= complexityThreshold {
            return FlowModeRecommendation(
                mode: .mesh,
                confidence: 0.8,
                rationale: "Mission involves cross-functional coordination or complex constraints"
            )
        } else if crossFunctionalScore >= 1 {
            return FlowModeRecommendation(
                mode: .hybrid,
                confidence: 0.7,
                rationale: "Mission has some cross-functional elements; hybrid mode recommended"
            )
        } else {
            return FlowModeRecommendation(
                mode: .org,
                confidence: 0.9,
                rationale: "Standard staff-lane workflow appropriate for this mission"
            )
        }
    }
}

public struct FlowModeRecommendation: Codable, Sendable {
    public var mode: FlowMode
    public var confidence: Double
    public var rationale: String

    public init(mode: FlowMode, confidence: Double, rationale: String) {
        self.mode = mode
        self.confidence = confidence
        self.rationale = rationale
    }
}
