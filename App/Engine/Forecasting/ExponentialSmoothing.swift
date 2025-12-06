import Foundation

// MARK: - Exponential Smoothing Forecaster
// Implements Simple and Double Exponential Smoothing for time series forecasting.

/// Simple Exponential Smoothing (SES) forecaster
/// Good for data without trend or seasonality
public struct SimpleExponentialSmoothing: TimeSeriesForecaster {
    public var alpha: Double  // Smoothing parameter (0-1)
    private var level: Double = 0
    private var fitted: Bool = false
    private var residualVariance: Double = 0

    public init(alpha: Double = 0.3) {
        self.alpha = max(0.01, min(0.99, alpha))
    }

    public mutating func fit(history: [DataPoint]) {
        guard !history.isEmpty else { return }

        let values = history.map(\.value)

        // Initialize level with first observation
        level = values[0]

        // Calculate fitted values and residuals
        var residuals: [Double] = []

        for i in 1..<values.count {
            let forecast = level
            let actual = values[i]
            residuals.append(actual - forecast)

            // Update level
            level = alpha * actual + (1 - alpha) * level
        }

        // Calculate residual variance for confidence intervals
        if !residuals.isEmpty {
            let meanResidual = residuals.reduce(0, +) / Double(residuals.count)
            let squaredDiffs = residuals.map { pow($0 - meanResidual, 2) }
            residualVariance = squaredDiffs.reduce(0, +) / Double(residuals.count)
        }

        fitted = true
    }

    public func forecast(history: [DataPoint], horizon: Int) -> [ForecastPoint] {
        guard !history.isEmpty, horizon > 0 else { return [] }

        var forecaster = self
        if !fitted {
            forecaster.fit(history: history)
        }

        let values = history.map(\.value)
        var currentLevel = forecaster.level

        // Recalculate level if not fitted
        if !fitted {
            currentLevel = values[0]
            for value in values.dropFirst() {
                currentLevel = forecaster.alpha * value + (1 - forecaster.alpha) * currentLevel
            }
        }

        // Generate forecasts
        var results: [ForecastPoint] = []
        let lastTimestamp = history.last?.timestamp ?? Date()
        let stdDev = sqrt(forecaster.residualVariance)

        for h in 1...horizon {
            // For SES, all future forecasts are the same (flat)
            let predicted = currentLevel

            // Confidence intervals widen with horizon
            // SE(h) = sigma * sqrt(1 + (h-1) * alpha^2)
            let se = stdDev * sqrt(1 + Double(h - 1) * pow(forecaster.alpha, 2))
            let z = 1.96  // 95% CI

            let futureDate = Calendar.current.date(
                byAdding: .day,
                value: h,
                to: lastTimestamp
            ) ?? lastTimestamp

            // Confidence decreases with horizon
            let confidence = max(0.5, 1.0 - (Double(h) * 0.02))

            results.append(ForecastPoint(
                timestamp: futureDate,
                predicted: predicted,
                lowerBound: predicted - z * se,
                upperBound: predicted + z * se,
                confidence: confidence
            ))
        }

        return results
    }
}

/// Double Exponential Smoothing (Holt's method)
/// Good for data with linear trend but no seasonality
public struct DoubleExponentialSmoothing: TimeSeriesForecaster {
    public var alpha: Double  // Level smoothing
    public var beta: Double   // Trend smoothing
    private var level: Double = 0
    private var trend: Double = 0
    private var fitted: Bool = false
    private var residualVariance: Double = 0

    public init(alpha: Double = 0.3, beta: Double = 0.1) {
        self.alpha = max(0.01, min(0.99, alpha))
        self.beta = max(0.01, min(0.99, beta))
    }

    public mutating func fit(history: [DataPoint]) {
        guard history.count >= 2 else { return }

        let values = history.map(\.value)

        // Initialize
        level = values[0]
        trend = values[1] - values[0]

        var residuals: [Double] = []

        for i in 1..<values.count {
            let forecast = level + trend
            let actual = values[i]
            residuals.append(actual - forecast)

            // Update level and trend
            let newLevel = alpha * actual + (1 - alpha) * (level + trend)
            let newTrend = beta * (newLevel - level) + (1 - beta) * trend

            level = newLevel
            trend = newTrend
        }

        // Calculate residual variance
        if !residuals.isEmpty {
            let meanResidual = residuals.reduce(0, +) / Double(residuals.count)
            let squaredDiffs = residuals.map { pow($0 - meanResidual, 2) }
            residualVariance = squaredDiffs.reduce(0, +) / Double(residuals.count)
        }

        fitted = true
    }

    public func forecast(history: [DataPoint], horizon: Int) -> [ForecastPoint] {
        guard history.count >= 2, horizon > 0 else { return [] }

        var forecaster = self
        if !fitted {
            forecaster.fit(history: history)
        }

        let values = history.map(\.value)
        var currentLevel = forecaster.level
        var currentTrend = forecaster.trend

        // Recalculate if not fitted
        if !fitted {
            currentLevel = values[0]
            currentTrend = values[1] - values[0]

            for i in 1..<values.count {
                let newLevel = forecaster.alpha * values[i] + (1 - forecaster.alpha) * (currentLevel + currentTrend)
                let newTrend = forecaster.beta * (newLevel - currentLevel) + (1 - forecaster.beta) * currentTrend
                currentLevel = newLevel
                currentTrend = newTrend
            }
        }

        // Generate forecasts
        var results: [ForecastPoint] = []
        let lastTimestamp = history.last?.timestamp ?? Date()
        let stdDev = sqrt(forecaster.residualVariance)

        for h in 1...horizon {
            let predicted = currentLevel + Double(h) * currentTrend

            // Standard error for Holt's method
            let se = stdDev * sqrt(1 + Double(h - 1) * pow(forecaster.alpha + forecaster.alpha * forecaster.beta, 2))
            let z = 1.96

            let futureDate = Calendar.current.date(
                byAdding: .day,
                value: h,
                to: lastTimestamp
            ) ?? lastTimestamp

            let confidence = max(0.4, 1.0 - (Double(h) * 0.025))

            results.append(ForecastPoint(
                timestamp: futureDate,
                predicted: predicted,
                lowerBound: predicted - z * se,
                upperBound: predicted + z * se,
                confidence: confidence
            ))
        }

        return results
    }
}

/// Moving Average forecaster
/// Simple baseline model
public struct MovingAverageForecaster: TimeSeriesForecaster {
    public let windowSize: Int
    private var residualVariance: Double = 0
    private var fitted: Bool = false

    public init(windowSize: Int = 7) {
        self.windowSize = max(1, windowSize)
    }

    public mutating func fit(history: [DataPoint]) {
        guard history.count >= windowSize else { return }

        let values = history.map(\.value)
        var residuals: [Double] = []

        for i in windowSize..<values.count {
            let window = Array(values[(i - windowSize)..<i])
            let forecast = window.reduce(0, +) / Double(windowSize)
            residuals.append(values[i] - forecast)
        }

        if !residuals.isEmpty {
            let meanResidual = residuals.reduce(0, +) / Double(residuals.count)
            let squaredDiffs = residuals.map { pow($0 - meanResidual, 2) }
            residualVariance = squaredDiffs.reduce(0, +) / Double(residuals.count)
        }

        fitted = true
    }

    public func forecast(history: [DataPoint], horizon: Int) -> [ForecastPoint] {
        guard history.count >= windowSize, horizon > 0 else { return [] }

        var forecaster = self
        if !fitted {
            forecaster.fit(history: history)
        }

        let values = history.map(\.value)

        // Calculate moving average from last window
        let window = Array(values.suffix(windowSize))
        let ma = window.reduce(0, +) / Double(windowSize)

        var results: [ForecastPoint] = []
        let lastTimestamp = history.last?.timestamp ?? Date()
        let stdDev = sqrt(forecaster.residualVariance)

        for h in 1...horizon {
            // Moving average forecast is flat
            let predicted = ma

            // Standard error increases with horizon
            let se = stdDev * sqrt(1 + Double(h - 1) * 0.1)
            let z = 1.96

            let futureDate = Calendar.current.date(
                byAdding: .day,
                value: h,
                to: lastTimestamp
            ) ?? lastTimestamp

            let confidence = max(0.5, 1.0 - (Double(h) * 0.03))

            results.append(ForecastPoint(
                timestamp: futureDate,
                predicted: predicted,
                lowerBound: predicted - z * se,
                upperBound: predicted + z * se,
                confidence: confidence
            ))
        }

        return results
    }
}

/// Linear Regression forecaster
/// For data with clear linear trend
public struct LinearRegressionForecaster: TimeSeriesForecaster {
    private var slope: Double = 0
    private var intercept: Double = 0
    private var residualVariance: Double = 0
    private var fitted: Bool = false

    public init() {}

    public mutating func fit(history: [DataPoint]) {
        guard history.count >= 2 else { return }

        let values = history.map(\.value)
        let n = Double(values.count)

        // Simple linear regression
        let x = Array(0..<values.count).map { Double($0) }
        let y = values

        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return }

        slope = (n * sumXY - sumX * sumY) / denominator
        intercept = (sumY - slope * sumX) / n

        // Calculate residual variance
        var residuals: [Double] = []
        for i in 0..<values.count {
            let predicted = intercept + slope * Double(i)
            residuals.append(values[i] - predicted)
        }

        let meanResidual = residuals.reduce(0, +) / Double(residuals.count)
        let squaredDiffs = residuals.map { pow($0 - meanResidual, 2) }
        residualVariance = squaredDiffs.reduce(0, +) / Double(residuals.count)

        fitted = true
    }

    public func forecast(history: [DataPoint], horizon: Int) -> [ForecastPoint] {
        guard history.count >= 2, horizon > 0 else { return [] }

        var forecaster = self
        if !fitted {
            forecaster.fit(history: history)
        }

        let values = history.map(\.value)
        var currentSlope = forecaster.slope
        var currentIntercept = forecaster.intercept

        // Recalculate if not fitted
        if !fitted {
            let n = Double(values.count)
            let x = Array(0..<values.count).map { Double($0) }

            let sumX = x.reduce(0, +)
            let sumY = values.reduce(0, +)
            let sumXY = zip(x, values).map(*).reduce(0, +)
            let sumX2 = x.map { $0 * $0 }.reduce(0, +)

            let denominator = n * sumX2 - sumX * sumX
            if denominator != 0 {
                currentSlope = (n * sumXY - sumX * sumY) / denominator
                currentIntercept = (sumY - currentSlope * sumX) / n
            }
        }

        var results: [ForecastPoint] = []
        let lastTimestamp = history.last?.timestamp ?? Date()
        let stdDev = sqrt(forecaster.residualVariance)
        let n = values.count

        for h in 1...horizon {
            let futureX = Double(n + h - 1)
            let predicted = currentIntercept + currentSlope * futureX

            // Standard error for prediction
            let se = stdDev * sqrt(1.1 + Double(h) * 0.05)
            let z = 1.96

            let futureDate = Calendar.current.date(
                byAdding: .day,
                value: h,
                to: lastTimestamp
            ) ?? lastTimestamp

            let confidence = max(0.4, 1.0 - (Double(h) * 0.02))

            results.append(ForecastPoint(
                timestamp: futureDate,
                predicted: predicted,
                lowerBound: predicted - z * se,
                upperBound: predicted + z * se,
                confidence: confidence
            ))
        }

        return results
    }
}
