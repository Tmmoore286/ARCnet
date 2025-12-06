import Foundation
import ARCnetDomain
import ARCnetData

// MARK: - Forecast Service
// Orchestrates forecasting for various metrics and provides recommendations.

public actor ForecastService {
    private let dataGateway: DataGateway
    private var cache: [CacheKey: CachedForecast] = [:]
    private let cacheTTL: TimeInterval = 3600  // 1 hour

    public init(dataGateway: DataGateway) {
        self.dataGateway = dataGateway
    }

    // MARK: - Public Interface

    /// Generate forecast for a specific metric
    public func forecast(
        metric: ForecastMetric,
        unitId: String,
        config: ForecastConfig = ForecastConfig()
    ) async throws -> ForecastOutput {
        let cacheKey = CacheKey(metric: metric, unitId: unitId, model: config.model)

        // Check cache
        if let cached = cache[cacheKey], !cached.isExpired(ttl: cacheTTL) {
            return cached.forecast
        }

        // Fetch historical data
        let history = try await fetchHistory(metric: metric, unitId: unitId)

        guard history.count >= 2 else {
            throw ForecastError.insufficientData(required: 2, available: history.count)
        }

        // Select and run forecaster
        let forecaster = createForecaster(for: config.model)
        let forecast = forecaster.forecast(history: history, horizon: config.horizon)

        // Calculate accuracy on holdout set if we have enough data
        let accuracy = calculateAccuracy(
            history: history,
            model: config.model,
            holdoutSize: min(7, history.count / 4)
        )

        let output = ForecastOutput(
            metric: metric,
            unitId: unitId,
            history: history,
            forecast: forecast,
            modelUsed: config.model,
            accuracy: accuracy
        )

        // Cache result
        cache[cacheKey] = CachedForecast(forecast: output, timestamp: Date())

        return output
    }

    /// Generate forecasts for all metrics for a unit
    public func forecastAllMetrics(
        unitId: String,
        config: ForecastConfig = ForecastConfig()
    ) async throws -> [ForecastOutput] {
        var results: [ForecastOutput] = []

        for metric in ForecastMetric.allCases {
            do {
                let output = try await forecast(metric: metric, unitId: unitId, config: config)
                results.append(output)
            } catch ForecastError.insufficientData {
                // Skip metrics without enough data
                continue
            }
        }

        return results
    }

    /// Get trend analysis for a metric
    public func analyzeTrend(
        metric: ForecastMetric,
        unitId: String
    ) async throws -> TrendAnalysis {
        let history = try await fetchHistory(metric: metric, unitId: unitId)

        guard history.count >= 3 else {
            throw ForecastError.insufficientData(required: 3, available: history.count)
        }

        let values = history.map(\.value)

        // Calculate trend direction
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))

        let firstMean = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondMean = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let direction: TrendDirection
        let percentChange = (secondMean - firstMean) / firstMean * 100

        if percentChange > 5 {
            direction = .improving
        } else if percentChange < -5 {
            direction = .declining
        } else {
            direction = .stable
        }

        // Calculate volatility (coefficient of variation)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        let volatility = mean != 0 ? stdDev / abs(mean) : 0

        // Calculate momentum (recent vs longer term)
        let recent = Array(values.suffix(7))
        let longer = Array(values.suffix(30))
        let recentMean = recent.reduce(0, +) / Double(max(1, recent.count))
        let longerMean = longer.reduce(0, +) / Double(max(1, longer.count))
        let momentum = longerMean != 0 ? (recentMean - longerMean) / longerMean : 0

        return TrendAnalysis(
            metric: metric,
            direction: direction,
            percentChange: percentChange,
            volatility: volatility,
            momentum: momentum,
            dataPoints: history.count
        )
    }

    /// Recommend best forecasting model for given data
    public func recommendModel(
        metric: ForecastMetric,
        unitId: String
    ) async throws -> ModelRecommendation {
        let history = try await fetchHistory(metric: metric, unitId: unitId)

        guard history.count >= 10 else {
            // Not enough data for model comparison, use simple model
            return ModelRecommendation(
                recommended: .movingAverage,
                reason: "Insufficient data for model comparison",
                modelScores: [.movingAverage: 1.0]
            )
        }

        // Compare models using cross-validation
        var scores: [ForecastModel: Double] = [:]

        for model in ForecastModel.allCases {
            if model == .holtWinters { continue }  // Skip unimplemented

            let accuracy = calculateAccuracy(
                history: history,
                model: model,
                holdoutSize: min(7, history.count / 4)
            )

            if let acc = accuracy {
                // Lower MAPE is better, so invert for scoring
                scores[model] = 1.0 / (1.0 + acc.mape)
            }
        }

        // Find best model
        let best = scores.max { $0.value < $1.value }?.key ?? .exponentialSmoothing

        // Determine reason
        let trend = try? await analyzeTrend(metric: metric, unitId: unitId)
        let reason: String
        switch best {
        case .exponentialSmoothing:
            reason = "Data shows moderate variation without strong trend"
        case .movingAverage:
            reason = "Data is relatively stable with low volatility"
        case .linearRegression:
            reason = "Data shows clear linear trend"
        case .holtWinters:
            reason = "Data shows trend and seasonal patterns"
        }

        return ModelRecommendation(
            recommended: best,
            reason: reason,
            modelScores: scores,
            trendAnalysis: trend
        )
    }

    /// Clear forecast cache
    public func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private Methods

    private func fetchHistory(metric: ForecastMetric, unitId: String) async throws -> [DataPoint] {
        // Generate synthetic historical data based on metric type
        // In production, this would fetch from actual data sources
        let generator = HistoricalDataGenerator()
        return generator.generate(metric: metric, unitId: unitId, days: 90)
    }

    private func createForecaster(for model: ForecastModel) -> any TimeSeriesForecaster {
        switch model {
        case .exponentialSmoothing:
            return SimpleExponentialSmoothing(alpha: 0.3)
        case .movingAverage:
            return MovingAverageForecaster(windowSize: 7)
        case .linearRegression:
            return LinearRegressionForecaster()
        case .holtWinters:
            return DoubleExponentialSmoothing(alpha: 0.3, beta: 0.1)
        }
    }

    private func calculateAccuracy(
        history: [DataPoint],
        model: ForecastModel,
        holdoutSize: Int
    ) -> ForecastAccuracy? {
        guard history.count > holdoutSize + 2 else { return nil }

        let trainSize = history.count - holdoutSize
        let trainData = Array(history.prefix(trainSize))
        let testData = Array(history.suffix(holdoutSize))

        let forecaster = createForecaster(for: model)
        let predictions = forecaster.forecast(history: trainData, horizon: holdoutSize)

        guard predictions.count == testData.count else { return nil }

        var absoluteErrors: [Double] = []
        var squaredErrors: [Double] = []
        var percentageErrors: [Double] = []

        for (pred, actual) in zip(predictions, testData) {
            let error = abs(pred.predicted - actual.value)
            absoluteErrors.append(error)
            squaredErrors.append(pow(error, 2))
            if actual.value != 0 {
                percentageErrors.append(error / abs(actual.value) * 100)
            }
        }

        let mae = absoluteErrors.reduce(0, +) / Double(absoluteErrors.count)
        let rmse = sqrt(squaredErrors.reduce(0, +) / Double(squaredErrors.count))
        let mape = percentageErrors.isEmpty ? 0 : percentageErrors.reduce(0, +) / Double(percentageErrors.count)

        return ForecastAccuracy(mae: mae, rmse: rmse, mape: mape)
    }
}

// MARK: - Supporting Types

public enum ForecastError: Error {
    case insufficientData(required: Int, available: Int)
    case modelNotSupported(ForecastModel)
    case dataFetchFailed(String)
}

public enum TrendDirection: String, Sendable {
    case improving
    case stable
    case declining
}

public struct TrendAnalysis: Sendable {
    public let metric: ForecastMetric
    public let direction: TrendDirection
    public let percentChange: Double
    public let volatility: Double  // Coefficient of variation
    public let momentum: Double    // Recent vs longer term
    public let dataPoints: Int
}

public struct ModelRecommendation: Sendable {
    public let recommended: ForecastModel
    public let reason: String
    public let modelScores: [ForecastModel: Double]
    public let trendAnalysis: TrendAnalysis?

    public init(
        recommended: ForecastModel,
        reason: String,
        modelScores: [ForecastModel: Double],
        trendAnalysis: TrendAnalysis? = nil
    ) {
        self.recommended = recommended
        self.reason = reason
        self.modelScores = modelScores
        self.trendAnalysis = trendAnalysis
    }
}

// MARK: - Cache Support

private struct CacheKey: Hashable {
    let metric: ForecastMetric
    let unitId: String
    let model: ForecastModel
}

private struct CachedForecast {
    let forecast: ForecastOutput
    let timestamp: Date

    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Historical Data Generator

/// Generates synthetic historical data for forecasting
/// In production, this would be replaced with actual data fetching
struct HistoricalDataGenerator {
    func generate(metric: ForecastMetric, unitId: String, days: Int) -> [DataPoint] {
        var points: [DataPoint] = []
        let calendar = Calendar.current
        let today = Date()

        // Base value and variance by metric
        let (baseValue, variance, trend): (Double, Double, Double) = switch metric {
        case .readiness:
            (0.85, 0.05, 0.001)
        case .personnelStrength:
            (0.92, 0.03, -0.0005)
        case .equipmentMC:
            (0.80, 0.08, 0.002)
        case .fundsObligation:
            (500000, 20000, 5000)
        case .fundsExpenditure:
            (400000, 15000, 4000)
        case .maintenanceBacklog:
            (15, 5, -0.1)
        case .trainingCompletion:
            (0.75, 0.10, 0.003)
        }

        // Use unitId hash for consistent randomness per unit
        var seed = unitId.hashValue

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - i), to: today) else { continue }

            // Deterministic pseudo-random based on seed
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFFFFFF
            let random = Double(seed % 10000) / 10000.0 - 0.5  // -0.5 to 0.5

            // Add trend and noise
            var value = baseValue + trend * Double(i) + variance * random * 2

            // Add weekly seasonality for some metrics
            if metric == .readiness || metric == .trainingCompletion {
                let dayOfWeek = calendar.component(.weekday, from: date)
                if dayOfWeek == 1 || dayOfWeek == 7 {  // Weekend
                    value *= 0.95
                }
            }

            // Clamp percentage values
            if [.readiness, .personnelStrength, .equipmentMC, .trainingCompletion].contains(metric) {
                value = min(1.0, max(0.0, value))
            }

            // Clamp non-negative values
            value = max(0, value)

            points.append(DataPoint(timestamp: date, value: value, label: metric.rawValue))
        }

        return points
    }
}
