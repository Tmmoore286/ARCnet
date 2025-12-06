# Appendix D — ML Implementation & Maintenance Forecasting (Unclassified)

Objective
Forecast maintenance and readiness trajectories 2–12 weeks out; flag bottlenecks and mitigation windows that avoid TEEP degradation.

Data (unclassified aggregates)
- Availability time series; downtime categories; parts lead times; scheduled maintenance; training events; funding execution.

Feature Engineering
- Rolling stats, seasonal indicators, lag features; encoded event calendars (TEEP events, maintenance windows).

Models
- Tabular forecasting: Gradient Boosted Trees (XGBoost/LightGBM) for availability and backlog.
- Time‑series baselines: SARIMAX/Prophet‑style for trend/seasonality checks.
- Optional sequence model for log embeddings feeding a regression head (distilled, small footprint).

Training & Validation
- Cross‑unit and rolling‑origin splits; MAE/MAPE for numeric accuracy; recall/precision for risk windows.
- Ablations for feature importance; SHAP values for explainability (where feasible).

Deployment
- Export selected models as Core ML/ONNX artifacts or as a local service stub.
- Integrate model outputs into Specialists/Integrator with confidence and rationale.

Governance
- Version models/datasets; record provenance; refresh cadence defined.
- Guardrails: unclassified features only; no PII; documented assumptions and error bounds.

