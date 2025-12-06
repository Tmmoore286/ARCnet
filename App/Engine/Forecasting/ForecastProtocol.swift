import Foundation
import ARCnetDomain

// MARK: - Forecasting Protocols
// Defines interfaces for time-series forecasting used by specialist agents.

/// Protocol for time series forecasters
public protocol TimeSeriesForecaster: Sendable {
    /// Forecast future values from historical data
    /// - Parameters:
    ///   - history: Historical data points (value, timestamp)
    ///   - horizon: Number of periods to forecast
    /// - Returns: Array of forecasted values with confidence intervals
    func forecast(history: [DataPoint], horizon: Int) -> [ForecastPoint]

    /// Fit the model to historical data
    mutating func fit(history: [DataPoint])
}

/// A single data point in a time series
public struct DataPoint: Sendable, Codable {
    public let timestamp: Date
    public let value: Double
    public let label: String?

    public init(timestamp: Date, value: Double, label: String? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.label = label
    }
}

/// A forecasted point with confidence interval
public struct ForecastPoint: Sendable, Codable {
    public let timestamp: Date
    public let predicted: Double
    public let lowerBound: Double  // 95% CI lower
    public let upperBound: Double  // 95% CI upper
    public let confidence: Double  // 0-1 confidence score

    public init(
        timestamp: Date,
        predicted: Double,
        lowerBound: Double,
        upperBound: Double,
        confidence: Double
    ) {
        self.timestamp = timestamp
        self.predicted = predicted
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.confidence = confidence
    }
}

/// Types of forecast models available
public enum ForecastModel: String, Sendable, CaseIterable {
    case exponentialSmoothing = "exponential_smoothing"
    case movingAverage = "moving_average"
    case holtWinters = "holt_winters"
    case linearRegression = "linear_regression"
}

/// Metric types that can be forecasted
public enum ForecastMetric: String, Sendable, CaseIterable {
    case readiness = "readiness"
    case personnelStrength = "personnel_strength"
    case equipmentMC = "equipment_mc"
    case fundsObligation = "funds_obligation"
    case fundsExpenditure = "funds_expenditure"
    case maintenanceBacklog = "maintenance_backlog"
    case trainingCompletion = "training_completion"
}

/// Configuration for forecast generation
public struct ForecastConfig: Sendable {
    public let model: ForecastModel
    public let horizon: Int  // periods to forecast
    public let confidenceLevel: Double  // e.g., 0.95 for 95% CI
    public let seasonalPeriod: Int?  // for seasonal models

    public init(
        model: ForecastModel = .exponentialSmoothing,
        horizon: Int = 30,
        confidenceLevel: Double = 0.95,
        seasonalPeriod: Int? = nil
    ) {
        self.model = model
        self.horizon = horizon
        self.confidenceLevel = confidenceLevel
        self.seasonalPeriod = seasonalPeriod
    }
}

/// Result of a forecast operation
public struct ForecastOutput: Sendable {
    public let metric: ForecastMetric
    public let unitId: String
    public let generatedAt: Date
    public let history: [DataPoint]
    public let forecast: [ForecastPoint]
    public let modelUsed: ForecastModel
    public let accuracy: ForecastAccuracy?

    public init(
        metric: ForecastMetric,
        unitId: String,
        generatedAt: Date = Date(),
        history: [DataPoint],
        forecast: [ForecastPoint],
        modelUsed: ForecastModel,
        accuracy: ForecastAccuracy? = nil
    ) {
        self.metric = metric
        self.unitId = unitId
        self.generatedAt = generatedAt
        self.history = history
        self.forecast = forecast
        self.modelUsed = modelUsed
        self.accuracy = accuracy
    }
}

/// Forecast accuracy metrics
public struct ForecastAccuracy: Sendable {
    public let mae: Double   // Mean Absolute Error
    public let rmse: Double  // Root Mean Square Error
    public let mape: Double  // Mean Absolute Percentage Error

    public init(mae: Double, rmse: Double, mape: Double) {
        self.mae = mae
        self.rmse = rmse
        self.mape = mape
    }
}
