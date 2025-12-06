import Foundation
import ARCnetDomain

// MARK: - Composite Score Calculator
// Implements the S(i) formula from Enclosure 1 of the info paper.
// S(i) = w_sim·cos(vm,vi) + w_chain·Chain(i) + w_policy·Coverage(i) + w_ready·Avail(i) - w_load·Load(i)

public struct CompositeScoreCalculator: Sendable {
    private let weights: SelectionWeights

    public init(weights: SelectionWeights = SelectionWeights()) {
        self.weights = weights
    }

    /// Calculate composite score for a single agent candidate
    public func calculate(
        similarityScore: Float,
        chainScore: Float,
        coverageScore: Float,
        availabilityScore: Float,
        loadScore: Float
    ) -> Float {
        weights.similarity * similarityScore +
        weights.chain * chainScore +
        weights.policy * coverageScore +
        weights.readiness * availabilityScore -
        weights.load * loadScore
    }

    /// Calculate and populate scores for an agent candidate
    public func score(
        candidate: inout AgentCandidate,
        missionVector: [Float],
        agentVector: [Float],
        chainFit: Float,
        coverage: Float,
        availability: Float,
        load: Float
    ) {
        candidate.similarityScore = VectorMath.cosineSimilarity(missionVector, agentVector)
        candidate.chainScore = chainFit
        candidate.coverageScore = coverage
        candidate.availabilityScore = availability
        candidate.loadScore = load

        candidate.compositeScore = calculate(
            similarityScore: candidate.similarityScore,
            chainScore: candidate.chainScore,
            coverageScore: candidate.coverageScore,
            availabilityScore: candidate.availabilityScore,
            loadScore: candidate.loadScore
        )
    }
}

// MARK: - Chain of Command Scoring

public struct ChainOfCommandScorer: Sendable {

    public init() {}

    /// Calculate chain-of-command fit based on org structure
    /// Higher score for billets closer to mission-relevant sections
    public func score(
        node: OrgNode,
        missionShops: Set<String>,
        orgTree: OrgUnit
    ) -> Float {
        guard let shop = node.shop else { return 0.5 }

        // Direct match to mission-relevant shop
        if missionShops.contains(shop) {
            return 1.0
        }

        // Check if in chain of command for relevant shops
        if isInChainOfCommand(node: node, targetShops: missionShops, orgTree: orgTree) {
            return 0.75
        }

        // Staff section but not directly relevant
        if node.type == .billet {
            return 0.5
        }

        return 0.25
    }

    /// Determine if a node is in the chain of command for target shops
    private func isInChainOfCommand(
        node: OrgNode,
        targetShops: Set<String>,
        orgTree: OrgUnit
    ) -> Bool {
        // Build parent lookup
        var parentMap: [String: OrgNode] = [:]
        for n in orgTree.nodes {
            if let parentId = n.parentId {
                parentMap[n.id] = orgTree.nodes.first { $0.id == parentId }
            }
        }

        // Walk up chain
        var current: OrgNode? = node
        while let c = current {
            if let shop = c.shop, targetShops.contains(shop) {
                return true
            }
            current = parentMap[c.id]
        }

        return false
    }
}

// MARK: - Coverage Scoring

public struct CoverageScorer: Sendable {
    /// Required shops that must be covered
    public let requiredShops: Set<String>

    public init(requiredShops: Set<String> = ["S3", "S4"]) {
        self.requiredShops = requiredShops
    }

    /// Calculate coverage score based on whether agent covers required capabilities
    public func score(node: OrgNode, alreadyCovered: Set<String>) -> Float {
        guard let shop = node.shop else { return 0.5 }

        // High score if covering a required but uncovered shop
        if requiredShops.contains(shop) && !alreadyCovered.contains(shop) {
            return 1.0
        }

        // Medium score if covering any required shop
        if requiredShops.contains(shop) {
            return 0.75
        }

        // Lower score for non-required shops
        return 0.5
    }

    /// Identify which required shops are not yet covered
    public func uncoveredShops(from covered: Set<String>) -> Set<String> {
        requiredShops.subtracting(covered)
    }
}

// MARK: - Availability & Load Scoring

public struct AvailabilityScorer: Sendable {

    public init() {}

    /// Calculate availability score (0-1) based on autonomy mode and current status
    public func score(node: OrgNode) -> Float {
        switch node.autonomy {
        case .auto:
            return 1.0  // Fully available
        case .hotl:
            return 0.8  // Available with oversight
        case .hitl:
            return 0.6  // Requires approval, less available
        }
    }
}

public struct LoadScorer: Sendable {
    // Maps agent ID to current task count
    private var taskCounts: [String: Int]

    public init(taskCounts: [String: Int] = [:]) {
        self.taskCounts = taskCounts
    }

    /// Calculate load score (0-1) where higher means more loaded
    public func score(agentId: String, maxTasks: Int = 5) -> Float {
        let currentTasks = taskCounts[agentId] ?? 0
        return min(1.0, Float(currentTasks) / Float(maxTasks))
    }

    /// Create scorer with initial task assignments
    public static func withTasks(_ tasks: [String: Int]) -> LoadScorer {
        LoadScorer(taskCounts: tasks)
    }
}
