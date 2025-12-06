# Validation & Metrics (Unclassified)

Objectives
- Accurate: status truths match SSOT; plans honor constraints; evidence is cited.
- Timely: results arrive within agreed SLOs; parallel work stays within rate limits.
- Useful: commanders rate outputs ≥ 4/5 on clarity/actionability; multiple viable COAs.

Metrics
- Status Accuracy: 100% match to SSOT for readiness/funding snapshots.
- Planning Handshake Strength (0–1): coverage 0.4, corroboration 0.2, specificity 0.2, compliance 0.2; threshold ≥ 0.6.
- Timeliness: status ≤ 5s to first checkpoint; Org planning ≤ 20s; Mesh planning (K≈6–8) ≤ 40s.
- Usefulness: commander/user rating ≥ 4/5; ≥ 2 viable COAs with quantified tradeoffs.
- Token/Cost: per‑stage token caps (specialist ≤ 800 in / ≤ 300 out; aggregator ≤ 600).

Test Strategy
- Deterministic status checks vs SSOT.
- Orchestrator integration (ordering, approvals, gating).
- MOS seeding: citations align with MOS doctrine; negatives fall back to general guidance.
- Mesh selection: must‑include coverage; diversity penalties; K caps.
- Performance: stage timings, token counts, error handling (missing key, rate limits).

Scenario Packs (Appendix A)
- Status‑only; Status+Plan (TEEP constraint); Logistics‑heavy; Readiness recovery.
- Each with expected winner/ranking, constraints, and evidence ids.

Success Criteria
- Meets accuracy/timeliness/usefulness metrics across scenarios.
- No policy violations (classification/ROE, must‑include coverage, HITL gates).

