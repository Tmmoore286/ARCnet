# Technical Approach (Unclassified)

Design Principles
- Single Source of Truth (SSOT): all inputs land in a versioned, unclassified store before analysis.
- Explainable agents: MOS‑scoped doctrine seeding; HITL approvals; structured checkpoints with evidence.
- Bounded compute: token budgets, capped parallelism, cached embeddings.
- Portability: approaches generalize to any command with G‑3/G‑4/G‑8 feeds.

Architecture Overview
- Data Layer (SSOT): unclassified snapshots for readiness, maintenance, TEEP, budgets; versioned imports.
- Doctrine Layer: curated doctrine and T&R excerpts (unclassified) mapped to MOS/billets; provenance tracked.
- Reasoning Layer (Agents): staged flow (Scribe → Coordinator → Specialists → Integrator → Evaluator → COA → Tasking) with checkpoints.
- ML Layer: maintenance/readiness forecasting that feeds the Specialists and Integrator.
- UI/Exports: status dashboards, checkpoint timeline, COA comparison, tasking exports, JSONL logs.

Agent Seeding & Activation
- MOS‑scoped seeding: only billets with matching MOS receive T&R/METL doctrine.
- Coordinator activation:
  - Compute mission/request embedding and compare (cosine) with doctrine centroids.
  - Score billets S(i) = w_chain·f_chain + w_sim·cos + w_policy·coverage + w_ready·availability − w_load·penalty.
  - Select top‑K per shop with must‑include coverage; cap overall K; record rationale.

LLM Usage (MVP constraints)
- OpenAI only; structured prompts with strict schemas; evidence citations (docId/section/quote).
- HITL gates: every stage defaults to requiresApproval.
- Caching and budgeting: token caps per stage; parallelism throttled to respect rate limits.

Machine Learning Implementation (Maintenance & Readiness Forecasting)
- Goals
  - Predict equipment/platform availability and maintenance backlog trajectories (2–12 weeks out).
  - Identify mitigation windows that do not degrade TEEP.
- Features (unclassified)
  - Historical availability, downtime categories, parts lead times, scheduled maintenance windows, training events, funding execution.
- Candidate Models (train offline; deploy as Core ML/ONNX or service stub)
  - Gradient boosted trees (e.g., XGBoost/LightGBM) for tabular readiness metrics.
  - Time‑series models (SARIMAX, Prophet‑style, or tree‑based TS) for trend/seasonality.
  - Optional sequence models for long maintenance logs (distilled embeddings + regression head).
- Process
  - Data prep → train/validate (cross‑unit splits) → select model → export artifact → integrate into Specialists/Integrator for forecast and risk scoring.
  - Compare forecasts vs hold‑out periods; error metrics (MAE/MAPE); operational metrics (recall of risk windows).
- Outputs to Reasoning Layer
  - Forecasted availability curves, backlog risk flags, candidate mitigation windows with confidence.

Workflow Modes
- Org (default): sequential staff lanes with coverage.
- Mesh: similarity‑gated regions, parallel Specialists, crowd aggregation, policy‑bounded.
- Hybrid: Org for status, Mesh for planning; FlowAdvisor can recommend a mode with rationale.

Explainability & Logging
- Each checkpoint: stage, summary, confidence, evidence[], classification, gate.
- “Handshake strength” metric: coverage, corroboration, specificity, compliance (threshold‑gated).
- JSONL logs for audit; exports include COA rationale and citations.

