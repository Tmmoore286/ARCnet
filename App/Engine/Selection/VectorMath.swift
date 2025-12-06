import Foundation
import Accelerate

// MARK: - Vector Math Utilities
// High-performance vector operations using Accelerate framework.
// Used for embedding similarity calculations.

public enum VectorMath {

    // MARK: - Cosine Similarity

    /// Compute cosine similarity between two vectors
    /// Returns value in range [-1, 1] where 1 means identical direction
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0

        // Use Accelerate for SIMD operations
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &magnitudeA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &magnitudeB, vDSP_Length(b.count))

        let denominator = sqrt(magnitudeA) * sqrt(magnitudeB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// Compute cosine distance (1 - similarity)
    /// Returns value in range [0, 2] where 0 means identical
    public static func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
        1 - cosineSimilarity(a, b)
    }

    // MARK: - Vector Normalization

    /// Normalize a vector to unit length
    public static func normalize(_ v: [Float]) -> [Float] {
        guard !v.isEmpty else { return v }

        var magnitude: Float = 0
        vDSP_dotpr(v, 1, v, 1, &magnitude, vDSP_Length(v.count))
        magnitude = sqrt(magnitude)

        guard magnitude > 0 else { return v }

        var result = [Float](repeating: 0, count: v.count)
        var scalar = 1.0 / magnitude
        vDSP_vsmul(v, 1, &scalar, &result, 1, vDSP_Length(v.count))

        return result
    }

    // MARK: - Centroid Computation

    /// Compute the centroid (mean) of multiple vectors
    public static func centroid(_ vectors: [[Float]]) -> [Float]? {
        guard let first = vectors.first, !first.isEmpty else { return nil }
        let dimension = first.count

        // Verify all vectors have same dimension
        guard vectors.allSatisfy({ $0.count == dimension }) else { return nil }

        var sum = [Float](repeating: 0, count: dimension)

        for vector in vectors {
            vDSP_vadd(sum, 1, vector, 1, &sum, 1, vDSP_Length(dimension))
        }

        var count = Float(vectors.count)
        vDSP_vsdiv(sum, 1, &count, &sum, 1, vDSP_Length(dimension))

        return sum
    }

    /// Compute normalized centroid
    public static func normalizedCentroid(_ vectors: [[Float]]) -> [Float]? {
        guard let c = centroid(vectors) else { return nil }
        return normalize(c)
    }

    // MARK: - Batch Similarity

    /// Compute similarity of a query vector against multiple candidates
    /// Returns array of (index, similarity) pairs sorted by similarity descending
    public static func rankBySimilarity(
        query: [Float],
        candidates: [[Float]]
    ) -> [(index: Int, similarity: Float)] {
        let similarities = candidates.enumerated().map { (index, candidate) in
            (index: index, similarity: cosineSimilarity(query, candidate))
        }
        return similarities.sorted { $0.similarity > $1.similarity }
    }

    /// Filter candidates by minimum similarity threshold
    public static func filterBySimilarity(
        query: [Float],
        candidates: [[Float]],
        threshold: Float
    ) -> [(index: Int, similarity: Float)] {
        rankBySimilarity(query: query, candidates: candidates)
            .filter { $0.similarity >= threshold }
    }

    // MARK: - Diversity Penalty

    /// Compute total pairwise similarity for diversity penalty calculation
    /// Used in mesh mode to penalize redundant agent selection
    public static func pairwiseSimilaritySum(_ vectors: [[Float]]) -> Float {
        guard vectors.count > 1 else { return 0 }

        var totalSimilarity: Float = 0
        for i in 0..<vectors.count {
            for j in (i + 1)..<vectors.count {
                totalSimilarity += cosineSimilarity(vectors[i], vectors[j])
            }
        }
        return totalSimilarity
    }

    /// Compute marginal diversity gain of adding a new vector
    /// Lower is better (less redundant)
    public static func marginalRedundancy(
        newVector: [Float],
        existingVectors: [[Float]]
    ) -> Float {
        guard !existingVectors.isEmpty else { return 0 }

        var totalSimilarity: Float = 0
        for existing in existingVectors {
            totalSimilarity += cosineSimilarity(newVector, existing)
        }
        return totalSimilarity
    }

    // MARK: - Vector Arithmetic

    /// Add two vectors element-wise
    public static func add(_ a: [Float], _ b: [Float]) -> [Float] {
        guard a.count == b.count else { return a }
        var result = [Float](repeating: 0, count: a.count)
        vDSP_vadd(a, 1, b, 1, &result, 1, vDSP_Length(a.count))
        return result
    }

    /// Subtract two vectors element-wise (a - b)
    public static func subtract(_ a: [Float], _ b: [Float]) -> [Float] {
        guard a.count == b.count else { return a }
        var result = [Float](repeating: 0, count: a.count)
        vDSP_vsub(b, 1, a, 1, &result, 1, vDSP_Length(a.count))
        return result
    }

    /// Scale a vector by a scalar
    public static func scale(_ v: [Float], by scalar: Float) -> [Float] {
        var result = [Float](repeating: 0, count: v.count)
        var s = scalar
        vDSP_vsmul(v, 1, &s, &result, 1, vDSP_Length(v.count))
        return result
    }

    /// Compute magnitude (L2 norm) of a vector
    public static func magnitude(_ v: [Float]) -> Float {
        var dotProduct: Float = 0
        vDSP_dotpr(v, 1, v, 1, &dotProduct, vDSP_Length(v.count))
        return sqrt(dotProduct)
    }

    /// Compute Euclidean distance between two vectors
    public static func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        magnitude(subtract(a, b))
    }
}
