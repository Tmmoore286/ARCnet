"""FastAPI application for ARCnet ML forecasting service."""

from __future__ import annotations

import time
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from arcnet_ml.api.schemas import (
    ExplanationResponse,
    HealthResponse,
    MaintenancePredictionResponse,
    MetricsResponse,
    PredictMaintenanceRequest,
    RiskScoreResponse,
)
from arcnet_ml.data.synthetic import SyntheticDataGenerator
from arcnet_ml.etl.transforms import FeatureTransformer
from arcnet_ml.models.maintenance import MaintenanceForecaster

# ============================================================================
# Application State
# ============================================================================


class AppState:
    """Global application state."""

    def __init__(self) -> None:
        self.start_time = datetime.now()
        self.maintenance_model: MaintenanceForecaster | None = None
        self.feature_transformer = FeatureTransformer()
        self.data: dict[str, pd.DataFrame] = {}
        self.features_df: pd.DataFrame | None = None
        self.request_count = 0
        self.model_requests: dict[str, int] = {}
        self.total_latency_ms = 0.0


state = AppState()


# ============================================================================
# Lifespan
# ============================================================================


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize models and data on startup."""
    print("Initializing ARCnet ML service...")

    # Generate synthetic data for demo
    generator = SyntheticDataGenerator()
    state.data = generator.generate_all()
    print(f"  Generated {len(state.data)} datasets")

    # Prepare features
    state.features_df = state.feature_transformer.prepare_maintenance_features(
        readiness_df=state.data["readiness"],
        maintenance_df=state.data["maintenance"],
        teep_df=state.data["teep"],
    )
    print(f"  Prepared {len(state.features_df)} feature records")

    # Train maintenance model
    state.maintenance_model = MaintenanceForecaster()
    feature_cols = state.feature_transformer.get_feature_columns(state.features_df)

    # Remove rows with missing target
    train_df = state.features_df.dropna(subset=["availability_pct_target"])

    if len(train_df) > 0:
        X = train_df[feature_cols]
        y = train_df["availability_pct_target"]
        metrics = state.maintenance_model.train(X, y)
        print(f"  Trained maintenance model: MAE={metrics['mae']:.4f}, R²={metrics['r2']:.4f}")
    else:
        print("  Warning: No training data available")

    yield

    print("Shutting down ARCnet ML service...")


# ============================================================================
# FastAPI App
# ============================================================================


app = FastAPI(
    title="ARCnet ML Forecasting API",
    description="Predictive maintenance, budget, and risk forecasting for ARCnet",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Health & Metrics Endpoints
# ============================================================================


@app.get("/api/v1/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Check service health and model availability."""
    uptime = (datetime.now() - state.start_time).total_seconds()

    return HealthResponse(
        status="healthy",
        version="0.1.0",
        models_loaded={
            "maintenance": state.maintenance_model is not None
            and state.maintenance_model.is_trained,
            "budget": False,  # Not yet implemented
            "risk": False,  # Not yet implemented
        },
        uptime_seconds=uptime,
    )


@app.get("/api/v1/metrics", response_model=MetricsResponse)
async def get_metrics() -> MetricsResponse:
    """Get API usage metrics."""
    avg_latency = (
        state.total_latency_ms / state.request_count
        if state.request_count > 0
        else 0
    )

    return MetricsResponse(
        requests_total=state.request_count,
        requests_per_model=state.model_requests,
        average_latency_ms=avg_latency,
        error_rate=0.0,  # Simplified for now
        last_training={
            "maintenance": (
                state.maintenance_model.metadata.trained_at
                if state.maintenance_model and state.maintenance_model.metadata
                else None
            )
        },
    )


# ============================================================================
# Prediction Endpoints
# ============================================================================


@app.post("/api/v1/predict/maintenance", response_model=MaintenancePredictionResponse)
async def predict_maintenance(
    request: PredictMaintenanceRequest,
) -> MaintenancePredictionResponse:
    """Predict equipment availability for a unit."""
    start_time = time.time()
    state.request_count += 1
    state.model_requests["maintenance"] = state.model_requests.get("maintenance", 0) + 1

    if state.maintenance_model is None or not state.maintenance_model.is_trained:
        raise HTTPException(status_code=503, detail="Maintenance model not available")

    if state.features_df is None:
        raise HTTPException(status_code=503, detail="Feature data not loaded")

    try:
        result = state.maintenance_model.predict_for_unit(
            unit_id=request.unit_id,
            features_df=state.features_df,
            horizon_days=request.horizon_days,
        )

        if "error" in result:
            raise HTTPException(status_code=404, detail=result["error"])

        latency = (time.time() - start_time) * 1000
        state.total_latency_ms += latency

        return MaintenancePredictionResponse(
            unit_id=result["unit_id"],
            horizon_days=result["horizon_days"],
            platform_count=result["platform_count"],
            mean_availability=result["mean_availability"],
            min_availability=result["min_availability"],
            max_availability=result["max_availability"],
            mean_confidence=result["mean_confidence"],
            at_risk_platforms=result["at_risk_platforms"],
            predictions=[],  # Simplified response
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/predict/maintenance/{unit_id}")
async def predict_maintenance_get(
    unit_id: str, horizon: int = 14
) -> MaintenancePredictionResponse:
    """GET endpoint for maintenance prediction."""
    return await predict_maintenance(
        PredictMaintenanceRequest(unit_id=unit_id, horizon_days=horizon)
    )


@app.get("/api/v1/predict/risk/{unit_id}", response_model=RiskScoreResponse)
async def predict_risk(unit_id: str) -> RiskScoreResponse:
    """Get composite risk score for a unit."""
    state.request_count += 1
    state.model_requests["risk"] = state.model_requests.get("risk", 0) + 1

    # Get maintenance prediction as base for risk
    if state.maintenance_model and state.maintenance_model.is_trained and state.features_df is not None:
        maint_result = state.maintenance_model.predict_for_unit(
            unit_id=unit_id,
            features_df=state.features_df,
            horizon_days=14,
        )
        if "error" not in maint_result:
            maint_risk = 1 - maint_result["mean_availability"]
        else:
            maint_risk = 0.5
    else:
        maint_risk = 0.5

    # Simplified risk calculation (budget and TEEP not yet implemented)
    budget_risk = 0.3
    teep_risk = 0.2

    overall_risk = 0.5 * maint_risk + 0.3 * budget_risk + 0.2 * teep_risk

    if overall_risk < 0.25:
        risk_level = "low"
    elif overall_risk < 0.5:
        risk_level = "medium"
    elif overall_risk < 0.75:
        risk_level = "high"
    else:
        risk_level = "critical"

    return RiskScoreResponse(
        unit_id=unit_id,
        overall_risk=overall_risk,
        risk_level=risk_level,
        maintenance_risk=maint_risk,
        budget_risk=budget_risk,
        teep_risk=teep_risk,
        top_risk_factors=[
            "Equipment availability below target",
            "Upcoming TEEP events require additional platforms",
        ],
        recommended_actions=[
            "Prioritize preventive maintenance for at-risk platforms",
            "Review parts availability for critical systems",
        ],
    )


@app.get("/api/v1/explain/{prediction_id}", response_model=ExplanationResponse)
async def explain_prediction(prediction_id: str) -> ExplanationResponse:
    """Get SHAP-based explanation for a prediction."""
    # Simplified placeholder - in production would look up cached prediction
    return ExplanationResponse(
        prediction_id=prediction_id,
        shap_values={
            "availability_pct_lag_7d": 0.15,
            "downtime_30d": -0.12,
            "age_months": -0.08,
            "teep_events_30d": -0.05,
        },
        top_drivers=[
            {
                "feature": "availability_pct_lag_7d",
                "contribution": 0.15,
                "direction": "positive",
                "description": "Recent availability trend is favorable",
            },
            {
                "feature": "downtime_30d",
                "contribution": -0.12,
                "direction": "negative",
                "description": "Recent maintenance downtime affecting prediction",
            },
        ],
        narrative=(
            "The prediction is primarily driven by the recent availability trend "
            "over the past 7 days, which shows stable performance. However, "
            "accumulated downtime in the past 30 days is creating some downward "
            "pressure on the forecast. Equipment age is a minor negative factor."
        ),
    )


# ============================================================================
# Data Endpoints
# ============================================================================


@app.get("/api/v1/units")
async def list_units() -> list[dict[str, Any]]:
    """List available units."""
    if "units" not in state.data:
        return []

    return state.data["units"].to_dict(orient="records")


@app.get("/api/v1/platforms/{unit_id}")
async def list_platforms(unit_id: str) -> list[dict[str, Any]]:
    """List platforms for a unit."""
    if "platforms" not in state.data:
        return []

    platforms = state.data["platforms"]
    unit_platforms = platforms[platforms["unit_id"] == unit_id]
    return unit_platforms.to_dict(orient="records")


# ============================================================================
# Run Server
# ============================================================================


def run() -> None:
    """Run the API server."""
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    run()
