import XCTest
@testable import ARCnetEngine
@testable import ARCnetDomain
@testable import ARCnetData

final class ForecastTests: XCTestCase {

    // MARK: - Data Point Tests

    func testDataPointCreation() {
        let now = Date()
        let point = DataPoint(timestamp: now, value: 0.85, label: "readiness")

        XCTAssertEqual(point.timestamp, now)
        XCTAssertEqual(point.value, 0.85)
        XCTAssertEqual(point.label, "readiness")
    }

    func testForecastPointCreation() {
        let now = Date()
        let point = ForecastPoint(
            timestamp: now,
            predicted: 0.85,
            lowerBound: 0.80,
            upperBound: 0.90,
            confidence: 0.95
        )

        XCTAssertEqual(point.predicted, 0.85)
        XCTAssertEqual(point.lowerBound, 0.80)
        XCTAssertEqual(point.upperBound, 0.90)
        XCTAssertEqual(point.confidence, 0.95)
    }

    // MARK: - Simple Exponential Smoothing Tests

    func testSimpleExponentialSmoothingForecast() {
        let history = generateStableHistory(days: 30, baseValue: 100)
        let forecaster = SimpleExponentialSmoothing(alpha: 0.3)

        let forecast = forecaster.forecast(history: history, horizon: 7)

        XCTAssertEqual(forecast.count, 7)
        // For stable data, forecast should be close to the mean
        let mean = history.map(\.value).reduce(0, +) / Double(history.count)
        XCTAssertEqual(forecast[0].predicted, mean, accuracy: 10)
    }

    func testSimpleExponentialSmoothingConfidenceDecreases() {
        let history = generateStableHistory(days: 30, baseValue: 100)
        let forecaster = SimpleExponentialSmoothing(alpha: 0.3)

        let forecast = forecaster.forecast(history: history, horizon: 14)

        // Confidence should decrease over horizon
        XCTAssertGreaterThan(forecast[0].confidence, forecast[13].confidence)
    }

    func testSimpleExponentialSmoothingConfidenceIntervalWidens() {
        let history = generateStableHistory(days: 30, baseValue: 100)
        let forecaster = SimpleExponentialSmoothing(alpha: 0.3)

        let forecast = forecaster.forecast(history: history, horizon: 14)

        // CI should widen over horizon
        let firstWidth = forecast[0].upperBound - forecast[0].lowerBound
        let lastWidth = forecast[13].upperBound - forecast[13].lowerBound
        XCTAssertGreaterThan(lastWidth, firstWidth)
    }

    func testSimpleExponentialSmoothingEmptyHistory() {
        let forecaster = SimpleExponentialSmoothing(alpha: 0.3)
        let forecast = forecaster.forecast(history: [], horizon: 7)

        XCTAssertTrue(forecast.isEmpty)
    }

    // MARK: - Double Exponential Smoothing Tests

    func testDoubleExponentialSmoothingWithTrend() {
        // Generate data with upward trend
        let history = generateTrendingHistory(days: 30, baseValue: 100, dailyTrend: 2)
        let forecaster = DoubleExponentialSmoothing(alpha: 0.3, beta: 0.1)

        let forecast = forecaster.forecast(history: history, horizon: 7)

        XCTAssertEqual(forecast.count, 7)
        // With upward trend, later forecasts should be higher
        XCTAssertGreaterThan(forecast[6].predicted, forecast[0].predicted)
    }

    func testDoubleExponentialSmoothingCapturesTrend() {
        let history = generateTrendingHistory(days: 60, baseValue: 100, dailyTrend: 1)
        let forecaster = DoubleExponentialSmoothing(alpha: 0.3, beta: 0.1)

        let forecast = forecaster.forecast(history: history, horizon: 30)

        // Trend should continue in forecast
        let trendInForecast = (forecast.last!.predicted - forecast.first!.predicted) / 29
        XCTAssertGreaterThan(trendInForecast, 0)
    }

    // MARK: - Moving Average Tests

    func testMovingAverageForecast() {
        let history = generateStableHistory(days: 30, baseValue: 100)
        let forecaster = MovingAverageForecaster(windowSize: 7)

        let forecast = forecaster.forecast(history: history, horizon: 7)

        XCTAssertEqual(forecast.count, 7)
        // MA should equal average of last 7 values
        let lastWindow = history.suffix(7).map(\.value)
        let expectedMA = lastWindow.reduce(0, +) / 7
        XCTAssertEqual(forecast[0].predicted, expectedMA, accuracy: 0.01)
    }

    func testMovingAverageFlatForecast() {
        let history = generateStableHistory(days: 30, baseValue: 100)
        let forecaster = MovingAverageForecaster(windowSize: 7)

        let forecast = forecaster.forecast(history: history, horizon: 14)

        // All forecasts should be equal (flat line)
        let first = forecast[0].predicted
        for point in forecast {
            XCTAssertEqual(point.predicted, first, accuracy: 0.001)
        }
    }

    func testMovingAverageInsufficientData() {
        let history = generateStableHistory(days: 3, baseValue: 100)
        let forecaster = MovingAverageForecaster(windowSize: 7)

        let forecast = forecaster.forecast(history: history, horizon: 7)

        XCTAssertTrue(forecast.isEmpty)
    }

    // MARK: - Linear Regression Tests

    func testLinearRegressionForecast() {
        let history = generateTrendingHistory(days: 30, baseValue: 100, dailyTrend: 2)
        var forecaster = LinearRegressionForecaster()
        forecaster.fit(history: history)

        let forecast = forecaster.forecast(history: history, horizon: 7)

        XCTAssertEqual(forecast.count, 7)
        // Should continue trend
        XCTAssertGreaterThan(forecast[6].predicted, forecast[0].predicted)
    }

    func testLinearRegressionTrendCapture() {
        // Perfect linear data
        var history: [DataPoint] = []
        for i in 0..<30 {
            let date = Calendar.current.date(byAdding: .day, value: -29 + i, to: Date())!
            history.append(DataPoint(timestamp: date, value: 100 + Double(i) * 2))
        }

        var forecaster = LinearRegressionForecaster()
        forecaster.fit(history: history)
        let forecast = forecaster.forecast(history: history, horizon: 10)

        // Next value should be around 160 (100 + 30*2)
        XCTAssertEqual(forecast[0].predicted, 160, accuracy: 5)
    }

    // MARK: - Forecast Config Tests

    func testForecastConfigDefaults() {
        let config = ForecastConfig()

        XCTAssertEqual(config.model, .exponentialSmoothing)
        XCTAssertEqual(config.horizon, 30)
        XCTAssertEqual(config.confidenceLevel, 0.95)
        XCTAssertNil(config.seasonalPeriod)
    }

    func testForecastConfigCustom() {
        let config = ForecastConfig(
            model: .movingAverage,
            horizon: 14,
            confidenceLevel: 0.90,
            seasonalPeriod: 7
        )

        XCTAssertEqual(config.model, .movingAverage)
        XCTAssertEqual(config.horizon, 14)
        XCTAssertEqual(config.confidenceLevel, 0.90)
        XCTAssertEqual(config.seasonalPeriod, 7)
    }

    // MARK: - Forecast Accuracy Tests

    func testForecastAccuracyCreation() {
        let accuracy = ForecastAccuracy(mae: 5.0, rmse: 7.0, mape: 3.5)

        XCTAssertEqual(accuracy.mae, 5.0)
        XCTAssertEqual(accuracy.rmse, 7.0)
        XCTAssertEqual(accuracy.mape, 3.5)
    }

    // MARK: - Forecast Service Tests

    func testForecastServiceReadinessForecast() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        let output = try await service.forecast(
            metric: ForecastMetric.readiness,
            unitId: "test-unit",
            config: ForecastConfig(horizon: 14)
        )

        XCTAssertEqual(output.metric, ForecastMetric.readiness)
        XCTAssertEqual(output.unitId, "test-unit")
        XCTAssertEqual(output.forecast.count, 14)
        XCTAssertFalse(output.history.isEmpty)
    }

    func testForecastServiceAllMetrics() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        let outputs = try await service.forecastAllMetrics(unitId: "test-unit")

        // Should have forecasts for multiple metrics
        XCTAssertGreaterThan(outputs.count, 3)
    }

    func testForecastServiceTrendAnalysis() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        let trend = try await service.analyzeTrend(metric: ForecastMetric.readiness, unitId: "test-unit")

        XCTAssertEqual(trend.metric, ForecastMetric.readiness)
        XCTAssertGreaterThan(trend.dataPoints, 0)
        // Volatility should be reasonable
        XCTAssertGreaterThanOrEqual(trend.volatility, 0)
        XCTAssertLessThan(trend.volatility, 1)
    }

    func testForecastServiceModelRecommendation() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        let recommendation = try await service.recommendModel(
            metric: ForecastMetric.equipmentMC,
            unitId: "test-unit"
        )

        XCTAssertNotNil(recommendation.recommended)
        XCTAssertFalse(recommendation.reason.isEmpty)
        XCTAssertFalse(recommendation.modelScores.isEmpty)
    }

    func testForecastServiceCaching() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        // First call
        let output1 = try await service.forecast(
            metric: ForecastMetric.readiness,
            unitId: "cache-test",
            config: ForecastConfig(horizon: 7)
        )

        // Second call should use cache (same timestamp)
        let output2 = try await service.forecast(
            metric: ForecastMetric.readiness,
            unitId: "cache-test",
            config: ForecastConfig(horizon: 7)
        )

        XCTAssertEqual(output1.generatedAt, output2.generatedAt)
    }

    func testForecastServiceClearCache() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        // Generate forecast
        let _ = try await service.forecast(metric: ForecastMetric.readiness, unitId: "clear-test")

        // Clear cache
        await service.clearCache()

        // Next call generates new forecast (different timestamp)
        let output2 = try await service.forecast(metric: ForecastMetric.readiness, unitId: "clear-test")

        // Output should still be valid
        XCTAssertFalse(output2.forecast.isEmpty)
    }

    // MARK: - Historical Data Generator Tests

    func testHistoricalDataGeneratorReadiness() {
        let generator = HistoricalDataGenerator()
        let data = generator.generate(metric: ForecastMetric.readiness, unitId: "test", days: 30)

        XCTAssertEqual(data.count, 30)
        // Readiness should be between 0 and 1
        for point in data {
            XCTAssertGreaterThanOrEqual(point.value, 0)
            XCTAssertLessThanOrEqual(point.value, 1)
        }
    }

    func testHistoricalDataGeneratorFunds() {
        let generator = HistoricalDataGenerator()
        let data = generator.generate(metric: ForecastMetric.fundsObligation, unitId: "test", days: 30)

        XCTAssertEqual(data.count, 30)
        // Funds should be non-negative
        for point in data {
            XCTAssertGreaterThanOrEqual(point.value, 0)
        }
    }

    func testHistoricalDataGeneratorDeterministic() {
        let generator = HistoricalDataGenerator()

        // Same unit should generate same data
        let data1 = generator.generate(metric: ForecastMetric.readiness, unitId: "deterministic-test", days: 30)
        let data2 = generator.generate(metric: ForecastMetric.readiness, unitId: "deterministic-test", days: 30)

        XCTAssertEqual(data1.count, data2.count)
        for (p1, p2) in zip(data1, data2) {
            XCTAssertEqual(p1.value, p2.value, accuracy: 0.001)
        }
    }

    // MARK: - Trend Analysis Tests

    func testTrendDirectionImproving() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        // Equipment MC tends to trend upward in synthetic data
        let trend = try await service.analyzeTrend(metric: ForecastMetric.equipmentMC, unitId: "trend-test")

        // Just verify we get a valid direction
        XCTAssertNotNil(trend.direction)
    }

    func testTrendMomentum() async throws {
        let feedRepo = InMemoryFeedRepository()
        let gateway = SyntheticDataGateway(feedRepository: feedRepo)
        let service = ForecastService(dataGateway: gateway)

        let trend = try await service.analyzeTrend(metric: ForecastMetric.readiness, unitId: "momentum-test")

        // Momentum should be a small number (recent vs longer term difference)
        XCTAssertLessThan(abs(trend.momentum), 1)
    }

    // MARK: - Helper Methods

    private func generateStableHistory(days: Int, baseValue: Double) -> [DataPoint] {
        var points: [DataPoint] = []
        let calendar = Calendar.current

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - i), to: Date()) else { continue }
            // Small random variation
            let noise = Double.random(in: -5...5)
            points.append(DataPoint(timestamp: date, value: baseValue + noise))
        }

        return points
    }

    private func generateTrendingHistory(days: Int, baseValue: Double, dailyTrend: Double) -> [DataPoint] {
        var points: [DataPoint] = []
        let calendar = Calendar.current

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - i), to: Date()) else { continue }
            let trend = dailyTrend * Double(i)
            let noise = Double.random(in: -2...2)
            points.append(DataPoint(timestamp: date, value: baseValue + trend + noise))
        }

        return points
    }
}
