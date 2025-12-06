import Foundation
import ARCnetDomain
import ARCnetLLM
import ARCnetData

// MARK: - Embedding Service
// High-level service for managing embeddings with caching.

public actor EmbeddingService {
    private let client: EmbeddingClient
    private let doctrineRepository: DoctrineRepository
    private let config: EmbeddingConfig

    // In-memory cache for mission embeddings (ephemeral)
    private var missionCache: [String: [Float]] = [:]

    // Agent/billet embedding cache (keyed by node ID)
    private var agentCache: [String: [Float]] = [:]

    public init(
        client: EmbeddingClient,
        doctrineRepository: DoctrineRepository,
        config: EmbeddingConfig = .small
    ) {
        self.client = client
        self.doctrineRepository = doctrineRepository
        self.config = config
    }

    // MARK: - Mission Embedding

    /// Get or compute embedding for a mission statement
    public func embedMission(_ missionText: String) async throws -> [Float] {
        let cacheKey = missionText.hashValue.description

        if let cached = missionCache[cacheKey] {
            return cached
        }

        let embedding = try await client.embed(text: missionText, model: config.model)
        missionCache[cacheKey] = embedding
        return embedding
    }

    /// Clear mission cache (call after mission completes)
    public func clearMissionCache() {
        missionCache.removeAll()
    }

    // MARK: - Agent/Billet Embedding

    /// Get or compute embedding for an org node (billet)
    /// Uses cached doctrine vectors when available
    public func embedAgent(node: OrgNode) async throws -> [Float] {
        if let cached = agentCache[node.id] {
            return cached
        }

        // Try to get doctrine centroid for this MOS
        if let mos = node.mos, let centroid = try await doctrineRepository.computeCentroid(forMOS: mos) {
            agentCache[node.id] = centroid
            return centroid
        }

        // Fall back to embedding the billet description
        let description = buildAgentDescription(node)
        let embedding = try await client.embed(text: description, model: config.model)
        agentCache[node.id] = embedding
        return embedding
    }

    /// Pre-compute embeddings for all billets in an org unit
    public func precomputeAgentEmbeddings(for unit: OrgUnit) async throws {
        let billets = unit.nodes.filter { $0.type == .billet }

        for billet in billets {
            _ = try await embedAgent(node: billet)
        }
    }

    /// Clear agent cache
    public func clearAgentCache() {
        agentCache.removeAll()
    }

    // MARK: - Doctrine Embedding

    /// Embed doctrine text and store in repository
    public func embedDoctrine(
        docId: String,
        text: String,
        mosCode: String? = nil
    ) async throws -> DoctrineVector {
        let embedding = try await client.embed(text: text, model: config.model)

        let vector = DoctrineVector(
            mosCode: mosCode,
            docId: docId,
            vector: embedding,
            version: config.model
        )

        try await doctrineRepository.saveVector(vector)
        return vector
    }

    /// Batch embed multiple doctrine documents
    public func embedDoctrines(
        documents: [(docId: String, text: String, mosCode: String?)]
    ) async throws -> [DoctrineVector] {
        // Batch embed for efficiency
        let texts = documents.map(\.text)
        let embeddings = try await client.embed(texts: texts, model: config.model)

        var vectors: [DoctrineVector] = []
        for (index, doc) in documents.enumerated() {
            let vector = DoctrineVector(
                mosCode: doc.mosCode,
                docId: doc.docId,
                vector: embeddings[index],
                version: config.model
            )
            try await doctrineRepository.saveVector(vector)
            vectors.append(vector)
        }

        return vectors
    }

    // MARK: - Similarity Queries

    /// Find most similar agents to a mission
    public func findSimilarAgents(
        mission: String,
        agents: [OrgNode],
        threshold: Float = 0.0,
        limit: Int? = nil
    ) async throws -> [(node: OrgNode, similarity: Float)] {
        let missionVector = try await embedMission(mission)

        var results: [(node: OrgNode, similarity: Float)] = []

        for agent in agents {
            let agentVector = try await embedAgent(node: agent)
            let similarity = VectorMath.cosineSimilarity(missionVector, agentVector)

            if similarity >= threshold {
                results.append((node: agent, similarity: similarity))
            }
        }

        // Sort by similarity descending
        results.sort { $0.similarity > $1.similarity }

        if let limit = limit {
            return Array(results.prefix(limit))
        }
        return results
    }

    // MARK: - Private Helpers

    private func buildAgentDescription(_ node: OrgNode) -> String {
        var parts: [String] = []

        if let billet = node.billet {
            parts.append(billet)
        }

        if let shop = node.shop {
            parts.append("in \(shop) section")
        }

        if let mos = node.mos {
            parts.append("MOS \(mos)")
        }

        if !node.agentTemplates.isEmpty {
            parts.append("capabilities: \(node.agentTemplates.joined(separator: ", "))")
        }

        return parts.isEmpty ? node.name : parts.joined(separator: ", ")
    }
}

// MARK: - Embedding Service Factory

public struct EmbeddingServiceFactory {
    public static func create(
        apiKey: String,
        doctrineRepository: DoctrineRepository,
        config: EmbeddingConfig = .small
    ) -> EmbeddingService {
        let client = OpenAIEmbeddingClient(apiKey: apiKey)
        return EmbeddingService(
            client: client,
            doctrineRepository: doctrineRepository,
            config: config
        )
    }

    public static func createMock(
        doctrineRepository: DoctrineRepository,
        dimension: Int = 1536
    ) -> EmbeddingService {
        let client = MockEmbeddingClient(dimension: dimension)
        return EmbeddingService(
            client: client,
            doctrineRepository: doctrineRepository,
            config: EmbeddingConfig(dimension: dimension)
        )
    }
}
