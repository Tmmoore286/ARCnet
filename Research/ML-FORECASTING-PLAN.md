# ML Forecasting Implementation Plan

## Overview

This document outlines the implementation plan for ARCnet's predictive ML capabilities. The goal is to forecast maintenance needs, budget trajectories, and readiness risk 2-12 weeks ahead, enabling proactive decision support.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ML Forecasting Pipeline                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │ Data Sources │    │  ETL Layer   │    │  Feature     │                   │
│  │              │───▶│              │───▶│  Store       │                   │
│  │ • Maint logs │    │ • Ingestion  │    │              │                   │
│  │ • Budget     │    │ • Validation │    │ • Rolling    │                   │
│  │ • TEEP       │    │ • Transform  │    │   aggregates │                   │
│  │ • Readiness  │    │              │    │ • Lag feats  │                   │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                   │
│                                                  │                           │
│                      ┌───────────────────────────┼───────────────────────┐   │
│                      │                           ▼                       │   │
│                      │  ┌─────────────────────────────────────────────┐  │   │
│                      │  │              Model Registry                  │  │   │
│                      │  ├─────────────────────────────────────────────┤  │   │
│                      │  │                                             │  │   │
│                      │  │  ┌───────────────┐  ┌───────────────┐      │  │   │
│                      │  │  │ Maintenance   │  │ Budget        │      │  │   │
│                      │  │  │ Forecaster    │  │ Forecaster    │      │  │   │
│                      │  │  │ (XGBoost)     │  │ (SARIMAX)     │      │  │   │
│                      │  │  └───────┬───────┘  └───────┬───────┘      │  │   │
│                      │  │          │                  │              │  │   │
│                      │  │          ▼                  ▼              │  │   │
│                      │  │  ┌─────────────────────────────────────┐   │  │   │
│                      │  │  │         Risk Ensemble               │   │  │   │
│                      │  │  │   (Weighted combination + causal)   │   │  │   │
│                      │  │  └─────────────────┬───────────────────┘   │  │   │
│                      │  │                    │                       │  │   │
│                      │  └────────────────────┼───────────────────────┘  │   │
│                      │                       │                          │   │
│                      └───────────────────────┼──────────────────────────┘   │
│                                              │                              │
│                                              ▼                              │
│                      ┌─────────────────────────────────────────────────┐    │
│                      │                  API Layer                       │    │
│                      │  • /predict/maintenance                          │    │
│                      │  • /predict/budget                               │    │
│                      │  • /predict/risk                                 │    │
│                      │  • /explain/{prediction_id}                      │    │
│                      └─────────────────────────────────────────────────┘    │
│                                              │                              │
└──────────────────────────────────────────────┼──────────────────────────────┘
                                               │
                                               ▼
                              ┌─────────────────────────────────┐
                              │     ARCnet Agent Layer          │
                              │  (Specialists consume forecasts │
                              │   with confidence intervals)    │
                              └─────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation (ETL + Feature Store)

**Goal**: Establish data pipeline and feature engineering infrastructure.

| Task | Description | Deliverable |
|------|-------------|-------------|
| 1.1 | Create backend directory structure | `backend/` with modular layout |
| 1.2 | Implement file ingestion | Detect CSV/Excel, map columns to schema |
| 1.3 | Build staging layer | Raw → staging tables (all TEXT) |
| 1.4 | Create feature store | Computed features with versioning |
| 1.5 | Generate synthetic data | Realistic patterns for development |

**Key Features to Compute**:
- Rolling statistics (7d, 14d, 30d means/std)
- Lag features (availability t-7, t-14, t-30)
- Calendar encodings (day of week, month, fiscal quarter)
- Event indicators (TEEP proximity, maintenance windows)
- Cross-domain joins (equipment → budget → training)

### Phase 2: Maintenance Forecaster

**Goal**: Predict equipment availability and failure probability.

| Task | Description | Deliverable |
|------|-------------|-------------|
| 2.1 | Define prediction targets | Availability %, failure probability, downtime days |
| 2.2 | Build XGBoost pipeline | Train/eval with cross-validation |
| 2.3 | Implement SHAP explainability | Feature importance per prediction |
| 2.4 | Add confidence intervals | Quantile regression or conformal prediction |
| 2.5 | Create evaluation metrics | MAE, MAPE, precision/recall for risk flags |

**Model Specification**:
```python
# Target: availability_pct at t+14 days
# Features:
#   - availability_pct_lag_7, _14, _30
#   - downtime_hours_rolling_30d
#   - maintenance_events_upcoming
#   - parts_backlog_count
#   - age_months
#   - platform_type (categorical)
#   - fiscal_quarter
#   - teep_events_next_30d
```

### Phase 3: Budget Forecaster

**Goal**: Predict burn rate and end-of-period fund status.

| Task | Description | Deliverable |
|------|-------------|-------------|
| 3.1 | Define prediction targets | Monthly burn rate, EOY remaining funds |
| 3.2 | Build SARIMAX baseline | Capture seasonality and trend |
| 3.3 | Add XGBoost ensemble | Handle non-linear patterns |
| 3.4 | Implement anomaly detection | Flag unusual spending |
| 3.5 | Create scenario projections | What-if analysis for planning |

**Model Specification**:
```python
# Target: execution_rate at t+30 days
# Features:
#   - execution_rate_lag_30, _60, _90
#   - fiscal_quarter, fiscal_month
#   - appropriation_type
#   - planned_obligations_upcoming
#   - maintenance_forecast (from Phase 2)
#   - historical_same_period_rate
```

### Phase 4: Risk Ensemble

**Goal**: Combine forecasts into actionable readiness risk scores.

| Task | Description | Deliverable |
|------|-------------|-------------|
| 4.1 | Define composite risk metric | Weighted combination with domain logic |
| 4.2 | Build ensemble model | Stack maintenance + budget predictions |
| 4.3 | Add causal attribution | Which factors drive risk? |
| 4.4 | Implement risk ranking | Prioritize events/units by risk |
| 4.5 | Create alert thresholds | Configurable risk levels |

**Risk Score Formula**:
```
Risk(unit, t) = w_maint × MaintRisk(unit, t)
              + w_budget × BudgetRisk(unit, t)
              + w_teep × TEEPConflict(unit, t)
              + w_personnel × PersonnelGap(unit, t)
```

### Phase 5: API + Integration

**Goal**: Expose forecasts to ARCnet agents via REST API.

| Task | Description | Deliverable |
|------|-------------|-------------|
| 5.1 | Create FastAPI service | Endpoints for each model |
| 5.2 | Implement caching | Redis for repeated queries |
| 5.3 | Add request validation | Pydantic schemas |
| 5.4 | Build agent integration | Swift client for iOS app |
| 5.5 | Create health/metrics endpoints | Monitoring and observability |

**API Endpoints**:
```
GET  /api/v1/predict/maintenance/{unit_id}?horizon=14d
GET  /api/v1/predict/budget/{unit_id}?horizon=30d
GET  /api/v1/predict/risk/{unit_id}
GET  /api/v1/explain/{prediction_id}
POST /api/v1/scenario                         # What-if analysis
GET  /api/v1/health
GET  /api/v1/metrics
```

---

## Directory Structure

```
backend/
├── pyproject.toml              # Project config (uv/poetry)
├── requirements.txt            # Dependencies
│
├── arcnet_ml/
│   ├── __init__.py
│   │
│   ├── etl/                    # Data ingestion
│   │   ├── __init__.py
│   │   ├── ingestion.py        # File detection, loading
│   │   ├── transforms.py       # Staging → warehouse
│   │   ├── validation.py       # Data quality checks
│   │   └── configs/
│   │       ├── column_maps.yaml
│   │       └── file_patterns.yaml
│   │
│   ├── features/               # Feature engineering
│   │   ├── __init__.py
│   │   ├── store.py            # Feature store interface
│   │   ├── maintenance.py      # Maintenance features
│   │   ├── budget.py           # Budget features
│   │   └── calendar.py         # Temporal features
│   │
│   ├── models/                 # ML models
│   │   ├── __init__.py
│   │   ├── base.py             # Abstract forecaster
│   │   ├── maintenance.py      # XGBoost maintenance model
│   │   ├── budget.py           # SARIMAX budget model
│   │   ├── risk.py             # Risk ensemble
│   │   └── registry.py         # Model versioning
│   │
│   ├── explain/                # Explainability
│   │   ├── __init__.py
│   │   ├── shap_explain.py     # SHAP values
│   │   └── causal.py           # Causal attribution
│   │
│   └── api/                    # REST API
│       ├── __init__.py
│       ├── main.py             # FastAPI app
│       ├── routes/
│       │   ├── predict.py
│       │   ├── explain.py
│       │   └── health.py
│       └── schemas.py          # Pydantic models
│
├── tests/
│   ├── test_etl.py
│   ├── test_features.py
│   ├── test_models.py
│   └── test_api.py
│
├── notebooks/
│   ├── 01_eda.ipynb            # Exploratory analysis
│   ├── 02_feature_dev.ipynb    # Feature engineering
│   ├── 03_model_dev.ipynb      # Model development
│   └── 04_evaluation.ipynb     # Model evaluation
│
├── data/
│   ├── raw/                    # Input files
│   ├── processed/              # Transformed data
│   └── synthetic/              # Generated test data
│
└── models/                     # Trained model artifacts
    ├── maintenance_v1.joblib
    ├── budget_v1.joblib
    └── risk_v1.joblib
```

---

## Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Package Manager** | uv | Fast, modern Python packaging |
| **Data Processing** | pandas, polars | DataFrame operations |
| **ML Models** | XGBoost, scikit-learn | Gradient boosting, pipelines |
| **Time Series** | statsmodels, prophet | SARIMAX, decomposition |
| **Explainability** | SHAP | Feature importance, local explanations |
| **API** | FastAPI | Async, auto-docs, Pydantic validation |
| **Database** | DuckDB (dev), PostgreSQL (prod) | Analytical queries |
| **Testing** | pytest | Unit and integration tests |
| **Model Export** | ONNX, Core ML | iOS integration |

---

## Synthetic Data Generation

For development without real data:

```python
# Maintenance patterns
- Base availability: 85% ± 10%
- Seasonal dip: -5% in Q4 (fiscal year-end maintenance surge)
- Age degradation: -0.5% per year of platform age
- Random failures: Poisson(λ=0.1 per week)
- Correlated parts delays: 30% of failures have 2-week parts wait

# Budget patterns
- Execution curve: S-shaped (slow start, ramp, year-end push)
- Quarterly variance: ±8%
- Maintenance correlation: high maintenance → faster burn
- Random obligations: log-normal distribution

# TEEP events
- 4-6 major events per quarter
- Resource requirements: uniform(10, 50) personnel
- Equipment requirements: subset of available platforms
```

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Maintenance MAE | < 5% availability | Cross-validated on held-out months |
| Budget MAPE | < 10% | Rolling 30-day forecast accuracy |
| Risk Precision | > 70% | Flagged risks that materialized |
| Risk Recall | > 80% | Actual problems that were flagged |
| Inference Latency | < 200ms | 95th percentile API response |
| Explanation Coverage | 100% | All predictions have SHAP values |

---

## Integration with ARCnet Agents

Specialists will query forecasts during their reasoning:

```swift
// In LogisticsSpecialist
let forecast = try await mlClient.predictMaintenance(
    unitId: mission.unitId,
    horizon: .days(14)
)

// Incorporate into assessment
if forecast.availabilityPct < 0.80 && forecast.confidence > 0.7 {
    evidence.append(Evidence(
        source: "ML Forecast",
        content: "Predicted availability drop to \(forecast.availabilityPct)% " +
                 "within 14 days (confidence: \(forecast.confidence))",
        citation: "maintenance_forecast_\(forecast.id)"
    ))
    recommendations.append("Consider accelerating preventive maintenance")
}
```

---

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1: Foundation | 2-3 days | None |
| Phase 2: Maintenance | 2-3 days | Phase 1 |
| Phase 3: Budget | 2 days | Phase 1 |
| Phase 4: Risk Ensemble | 1-2 days | Phases 2, 3 |
| Phase 5: API + Integration | 2 days | Phase 4 |

**Total**: ~10-12 days of focused development

---

## Next Steps

1. Create `backend/` directory structure
2. Set up Python environment with uv
3. Implement synthetic data generator
4. Build Phase 1 ETL pipeline
5. Develop maintenance forecaster (Phase 2)

Ready to begin implementation on your signal.
