import XCTest
@testable import ARCnetDomain
@testable import ARCnetLLM
@testable import ARCnetEngine
@testable import ARCnetData

final class EmbeddingTests: XCTestCase {

    // MARK: - Vector Math Tests

    func testCosineSimilarityIdentical() {
        let v = [Float](repeating: 1.0, count: 10)
        let similarity = VectorMath.cosineSimilarity(v, v)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOrthogonal() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let similarity = VectorMath.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOpposite() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        let similarity = VectorMath.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, -1.0, accuracy: 0.0001)
    }

    func testNormalization() {
        let v: [Float] = [3, 4, 0]  // Magnitude = 5
        let normalized = VectorMath.normalize(v)

        let magnitude = VectorMath.magnitude(normalized)
        XCTAssertEqual(magnitude, 1.0, accuracy: 0.0001)

        XCTAssertEqual(normalized[0], 0.6, accuracy: 0.0001)
        XCTAssertEqual(normalized[1], 0.8, accuracy: 0.0001)
    }

    func testCentroid() {
        let vectors: [[Float]] = [
            [1, 0, 0],
            [0, 1, 0],
            [0, 0, 1]
        ]

        let centroid = VectorMath.centroid(vectors)
        XCTAssertNotNil(centroid)
        XCTAssertEqual(centroid![0], 1.0/3.0, accuracy: 0.0001)
        XCTAssertEqual(centroid![1], 1.0/3.0, accuracy: 0.0001)
        XCTAssertEqual(centroid![2], 1.0/3.0, accuracy: 0.0001)
    }

    func testRankBySimilarity() {
        let query: [Float] = [1, 0, 0]
        let candidates: [[Float]] = [
            [0, 1, 0],    // Orthogonal
            [0.9, 0.1, 0], // Very similar
            [0.5, 0.5, 0], // Somewhat similar
            [-1, 0, 0]     // Opposite
        ]

        let ranked = VectorMath.rankBySimilarity(query: query, candidates: candidates)

        XCTAssertEqual(ranked[0].index, 1)  // Most similar
        XCTAssertEqual(ranked[1].index, 2)  // Second most similar
        XCTAssertEqual(ranked[3].index, 3)  // Least similar (opposite)
    }

    func testPairwiseSimilaritySum() {
        // All identical vectors should have high pairwise similarity
        let identical: [[Float]] = [
            [1, 0, 0],
            [1, 0, 0],
            [1, 0, 0]
        ]
        let identicalSum = VectorMath.pairwiseSimilaritySum(identical)
        XCTAssertEqual(identicalSum, 3.0, accuracy: 0.0001)  // 3 pairs, each similarity = 1

        // Orthogonal vectors should have zero pairwise similarity
        let orthogonal: [[Float]] = [
            [1, 0, 0],
            [0, 1, 0],
            [0, 0, 1]
        ]
        let orthogonalSum = VectorMath.pairwiseSimilaritySum(orthogonal)
        XCTAssertEqual(orthogonalSum, 0.0, accuracy: 0.0001)
    }

    func testMarginalRedundancy() {
        let existing: [[Float]] = [
            [1, 0, 0],
            [0, 1, 0]
        ]

        // Adding similar vector should have high redundancy
        let similar: [Float] = [0.9, 0.1, 0]
        let highRedundancy = VectorMath.marginalRedundancy(newVector: similar, existingVectors: existing)
        XCTAssertGreaterThan(highRedundancy, 0.5)

        // Adding orthogonal vector should have low redundancy
        let orthogonal: [Float] = [0, 0, 1]
        let lowRedundancy = VectorMath.marginalRedundancy(newVector: orthogonal, existingVectors: existing)
        XCTAssertLessThan(lowRedundancy, 0.1)
    }

    func testVectorArithmetic() {
        let a: [Float] = [1, 2, 3]
        let b: [Float] = [4, 5, 6]

        let sum = VectorMath.add(a, b)
        XCTAssertEqual(sum, [5, 7, 9])

        let diff = VectorMath.subtract(a, b)
        XCTAssertEqual(diff, [-3, -3, -3])

        let scaled = VectorMath.scale(a, by: 2)
        XCTAssertEqual(scaled, [2, 4, 6])
    }

    func testEuclideanDistance() {
        let a: [Float] = [0, 0, 0]
        let b: [Float] = [3, 4, 0]

        let distance = VectorMath.euclideanDistance(a, b)
        XCTAssertEqual(distance, 5.0, accuracy: 0.0001)
    }

    // MARK: - Mock Embedding Client Tests

    func testMockEmbeddingClient() async throws {
        let client = MockEmbeddingClient(dimension: 128)

        let embeddings = try await client.embed(texts: ["hello", "world"], model: "test")

        XCTAssertEqual(embeddings.count, 2)
        XCTAssertEqual(embeddings[0].count, 128)
        XCTAssertEqual(embeddings[1].count, 128)

        // Embeddings should be normalized
        let magnitude1 = VectorMath.magnitude(embeddings[0])
        let magnitude2 = VectorMath.magnitude(embeddings[1])
        XCTAssertEqual(magnitude1, 1.0, accuracy: 0.001)
        XCTAssertEqual(magnitude2, 1.0, accuracy: 0.001)

        // Same text should produce same embedding (deterministic)
        let embedding1 = try await client.embed(text: "hello", model: "test")
        let embedding2 = try await client.embed(text: "hello", model: "test")
        XCTAssertEqual(embedding1, embedding2)
    }

    // MARK: - Embedding Service Tests

    func testEmbeddingServiceMissionEmbedding() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let service = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let embedding = try await service.embedMission("Conduct convoy escort operations")

        XCTAssertEqual(embedding.count, 64)

        // Should be cached
        let cached = try await service.embedMission("Conduct convoy escort operations")
        XCTAssertEqual(embedding, cached)
    }

    func testEmbeddingServiceAgentEmbedding() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let service = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let node = OrgNode(
            id: "B-S3-OPS",
            type: .billet,
            name: "Operations Officer",
            shop: "S3",
            billet: "Operations Officer",
            mos: "0302"
        )

        let embedding = try await service.embedAgent(node: node)

        XCTAssertEqual(embedding.count, 64)
    }

    func testEmbeddingServiceWithDoctrineCentroid() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let service = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 4
        )

        // Pre-save doctrine vectors for MOS
        let v1 = DoctrineVector(mosCode: "0302", docId: "doc1", vector: [1, 0, 0, 0])
        let v2 = DoctrineVector(mosCode: "0302", docId: "doc2", vector: [0, 1, 0, 0])
        try await doctrineRepo.saveVector(v1)
        try await doctrineRepo.saveVector(v2)

        let node = OrgNode(
            id: "B-S3-OPS",
            type: .billet,
            name: "Operations Officer",
            mos: "0302"
        )

        let embedding = try await service.embedAgent(node: node)

        // Should use doctrine centroid: [0.5, 0.5, 0, 0]
        XCTAssertEqual(embedding[0], 0.5, accuracy: 0.001)
        XCTAssertEqual(embedding[1], 0.5, accuracy: 0.001)
    }

    func testFindSimilarAgents() async throws {
        let doctrineRepo = InMemoryDoctrineRepository()
        let service = EmbeddingServiceFactory.createMock(
            doctrineRepository: doctrineRepo,
            dimension: 64
        )

        let agents = [
            OrgNode(id: "n1", type: .billet, name: "Operations Officer", shop: "S3", mos: "0302"),
            OrgNode(id: "n2", type: .billet, name: "Logistics Officer", shop: "S4", mos: "0402"),
            OrgNode(id: "n3", type: .billet, name: "Intel Officer", shop: "S2", mos: "0202")
        ]

        let results = try await service.findSimilarAgents(
            mission: "Plan convoy logistics support",
            agents: agents,
            limit: 2
        )

        XCTAssertEqual(results.count, 2)
        // Results should be sorted by similarity
        XCTAssertGreaterThanOrEqual(results[0].similarity, results[1].similarity)
    }

    // MARK: - Embedding Config Tests

    func testEmbeddingConfigDefaults() {
        let small = EmbeddingConfig.small
        XCTAssertEqual(small.model, "text-embedding-3-small")
        XCTAssertEqual(small.dimension, 1536)

        let large = EmbeddingConfig.large
        XCTAssertEqual(large.model, "text-embedding-3-large")
        XCTAssertEqual(large.dimension, 3072)
    }
}
