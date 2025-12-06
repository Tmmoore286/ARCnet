import Foundation

// MARK: - Embedding Client Protocol
// Protocol for generating text embeddings.

public protocol EmbeddingClient: Sendable {
    /// Generate embeddings for a batch of texts
    func embed(texts: [String], model: String) async throws -> [[Float]]

    /// Generate embedding for a single text
    func embed(text: String, model: String) async throws -> [Float]
}

public extension EmbeddingClient {
    func embed(text: String, model: String) async throws -> [Float] {
        let results = try await embed(texts: [text], model: model)
        guard let first = results.first else {
            throw EmbeddingClientError.emptyResponse
        }
        return first
    }
}

// MARK: - Embedding Client Errors

public enum EmbeddingClientError: Error, Sendable {
    case missingApiKey
    case badResponse
    case emptyResponse
    case rateLimited
    case invalidModel
}

// MARK: - OpenAI Embedding Client

public struct OpenAIEmbeddingClient: EmbeddingClient {
    private let apiKey: String
    private let baseURL: String

    public init(apiKey: String, baseURL: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func embed(texts: [String], model: String = "text-embedding-3-small") async throws -> [[Float]] {
        guard !apiKey.isEmpty else {
            throw EmbeddingClientError.missingApiKey
        }

        let url = URL(string: "\(baseURL)/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "input": texts
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingClientError.badResponse
        }

        if httpResponse.statusCode == 429 {
            throw EmbeddingClientError.rateLimited
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw EmbeddingClientError.badResponse
        }

        // Parse response
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = root["data"] as? [[String: Any]] else {
            throw EmbeddingClientError.badResponse
        }

        // Sort by index to maintain order
        let sortedData = dataArray.sorted { (a, b) -> Bool in
            let indexA = a["index"] as? Int ?? 0
            let indexB = b["index"] as? Int ?? 0
            return indexA < indexB
        }

        // Extract embeddings
        let embeddings: [[Float]] = try sortedData.map { item in
            guard let embedding = item["embedding"] as? [Double] else {
                throw EmbeddingClientError.badResponse
            }
            return embedding.map { Float($0) }
        }

        return embeddings
    }
}

// MARK: - Mock Embedding Client for Testing

public struct MockEmbeddingClient: EmbeddingClient {
    private let dimension: Int

    public init(dimension: Int = 1536) {
        self.dimension = dimension
    }

    public func embed(texts: [String], model: String) async throws -> [[Float]] {
        // Generate deterministic embeddings based on text hash for testing
        texts.map { text in
            var vector = [Float](repeating: 0, count: dimension)
            let hash = text.hashValue
            for i in 0..<dimension {
                // Generate pseudo-random but deterministic values
                let seed = hash &+ i
                vector[i] = Float(sin(Double(seed))) * 0.5 + 0.5
            }
            // Normalize
            let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
            return vector.map { $0 / magnitude }
        }
    }
}

// MARK: - Embedding Configuration

public struct EmbeddingConfig: Codable, Sendable {
    public var model: String
    public var dimension: Int

    public init(model: String = "text-embedding-3-small", dimension: Int = 1536) {
        self.model = model
        self.dimension = dimension
    }

    public static let small = EmbeddingConfig(model: "text-embedding-3-small", dimension: 1536)
    public static let large = EmbeddingConfig(model: "text-embedding-3-large", dimension: 3072)
}
