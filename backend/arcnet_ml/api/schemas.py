"""Pydantic schemas for API request/response validation."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field


# ============================================================================
# Request Schemas
# ============================================================================


class PredictMaintenanceRequest(BaseModel):
    """Request for maintenance availability prediction."""

    unit_id: str = Field(..., description="Unit identifier")
    horizon_days: int = Field(14, ge=1, le=90, description="Forecast horizon in days")
    platform_ids: list[str] | None = Field(
        None, description="Specific platforms to predict (optional)"
    )


class PredictBudgetRequest(BaseModel):
    """Request for budget execution prediction."""

    unit_id: str = Field(..., description="Unit identifier")
    appropriation: str = Field(..., description="Appropriation type (O&M, etc.)")
    horizon_days: int = Field(30, ge=1, le=365, description="Forecast horizon in days")


class PredictRiskRequest(BaseModel):
    """Request for composite risk scoring."""

    unit_id: str = Field(..., description="Unit identifier")
    include_components: bool = Field(
        True, description="Include component risk scores"
    )


class ScenarioRequest(BaseModel):
    """Request for what-if scenario analysis."""

    unit_id: str = Field(..., description="Unit identifier")
    scenario_type: str = Field(..., description="Type of scenario")
    parameters: dict[str, Any] = Field(
        default_factory=dict, description="Scenario parameters"
    )


# ============================================================================
# Response Schemas
# ============================================================================


class ForecastResponse(BaseModel):
    """Single prediction result."""

    prediction: float = Field(..., description="Predicted value")
    confidence: float = Field(..., ge=0, le=1, description="Prediction confidence")
    lower_bound: float = Field(..., description="Lower confidence bound")
    upper_bound: float = Field(..., description="Upper confidence bound")
    feature_importance: dict[str, float] = Field(
        default_factory=dict, description="Top feature importances"
    )


class MaintenancePredictionResponse(BaseModel):
    """Response for maintenance availability prediction."""

    unit_id: str
    horizon_days: int
    platform_count: int
    mean_availability: float = Field(..., ge=0, le=1)
    min_availability: float = Field(..., ge=0, le=1)
    max_availability: float = Field(..., ge=0, le=1)
    mean_confidence: float = Field(..., ge=0, le=1)
    at_risk_platforms: int = Field(..., ge=0)
    predictions: list[ForecastResponse]
    generated_at: datetime = Field(default_factory=datetime.now)


class BudgetPredictionResponse(BaseModel):
    """Response for budget execution prediction."""

    unit_id: str
    appropriation: str
    horizon_days: int
    predicted_execution_rate: float = Field(..., ge=0, le=1)
    predicted_remaining: float = Field(..., ge=0)
    confidence: float = Field(..., ge=0, le=1)
    trend: str = Field(..., description="on_track, underspend, overspend")
    generated_at: datetime = Field(default_factory=datetime.now)


class RiskScoreResponse(BaseModel):
    """Response for composite risk scoring."""

    unit_id: str
    overall_risk: float = Field(..., ge=0, le=1)
    risk_level: str = Field(..., description="low, medium, high, critical")
    maintenance_risk: float = Field(..., ge=0, le=1)
    budget_risk: float = Field(..., ge=0, le=1)
    teep_risk: float = Field(..., ge=0, le=1)
    top_risk_factors: list[str]
    recommended_actions: list[str]
    generated_at: datetime = Field(default_factory=datetime.now)


class ExplanationResponse(BaseModel):
    """Response for prediction explanation."""

    prediction_id: str
    shap_values: dict[str, float] = Field(
        default_factory=dict, description="SHAP feature contributions"
    )
    top_drivers: list[dict[str, Any]] = Field(
        default_factory=list, description="Top contributing factors"
    )
    narrative: str = Field(..., description="Human-readable explanation")


class HealthResponse(BaseModel):
    """API health check response."""

    status: str = Field(..., description="Service status")
    version: str = Field(..., description="API version")
    models_loaded: dict[str, bool] = Field(
        default_factory=dict, description="Model availability"
    )
    uptime_seconds: float = Field(..., ge=0)


class MetricsResponse(BaseModel):
    """API metrics response."""

    requests_total: int
    requests_per_model: dict[str, int]
    average_latency_ms: float
    error_rate: float
    last_training: dict[str, datetime | None]
