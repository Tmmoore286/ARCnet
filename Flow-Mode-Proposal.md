# Flow Mode Proposal — Org Path, Mesh (Crowd), and Hybrid

Status: Draft (do not implement yet)
Date: 2025-11-13

Purpose
- Capture a refined concept for letting the commander choose or be assisted in choosing the mission flow: Pure Org (chain-of-command), Mesh/Crowd (similarity-gated regions), or Hybrid.
- Define constraints, selection/activation logic, explainability, cost/latency impacts, and a safe path to evaluate this mode without breaking MVP guardrails.

Non‑Negotiable Guardrails
- SSOT: CoreData remains the single source of truth for roster, doctrine links, feeds, and checkpoints.
- Roster-bound: Agents exist only for billets in the selected unit + subtree. No synthetic agents are created.
- MOS‑scoped doctrine: Only agents with matching MOS get T&R/METL pre‑seeded doctrine; MOS‑agnostic stages use general guidance.
- HITL by default: Approval gates remain; commander can always override selection/flow.
- MVP network: Only OpenAI for embeddings/completions; no enterprise connectors/MCP.

User Story
- As a commander, when I enter a request (e.g., “What’s my current readiness and funding, and develop a plan to increase readiness without harming TEEP?”) I can:
  - Pick a flow (Org, Mesh, Hybrid), or
  - Choose “Let ARCnet choose (Assist Me)”, where a FlowAdvisor validates my inputs and recommends a mode with rationale.

Modes
- Org Path (default)
  - Sequential staff-lane flow honoring chain-of-command and shop coverage (e.g., G‑2/3/4/6/8 as policy dictates).
  - Best for factual status and routine, well‑scoped tasks.
- Mesh (Crowd)
  - Similarity‑gated activation of “regions” of specialists; run in parallel; merge via a CrowdAggregator.
  - Best for cross‑functional planning, time‑boxed ideation, and novel scenarios.
- Hybrid
  - Use Org for deterministic status pulls; use Mesh for planning/COA generation; converge through normal gates.

FlowAdvisor (Assisted Mode)
- Validates MissionContext (intent, endstate, constraints, acceptance criteria, CCIR); asks clarifying questions if missing/ambiguous.
- Scores flows and recommends Org/Mesh/Hybrid with explicit reasons and weights; commander can accept/override.

Activation & Selection Logic (Coordinator)
- Definitions (0–1, higher is better):
  - f_chain(i): chain-of-command fit for billet i (org distance to tasked unit, correct shop, echelon weighting).
  - s(i): cosine similarity between mission embedding and billet/MOS doctrine centroid.
  - c(i): policy/coverage weight (must/should‑include by mission type and gate).
  - r(i): readiness/availability from feeds.
  - l(i): load penalty (current workload).
- Composite score:
  - S(i) = w_chain·f_chain(i) + w_sim·s(i) + w_policy·c(i) + w_ready·r(i) − w_load·l(i)
- Suggested defaults:
  - Org Path: w_chain 0.4, w_sim 0.3, w_policy 0.2, w_ready 0.1, w_load 0.1
  - Mesh Path: w_chain 0.2, w_sim 0.45, w_policy 0.25, w_ready 0.1, w_load 0.1
  - Hybrid: Org weights for status stages; Mesh weights for planning stages.
- Region selection (Mesh):
  - Embed billets by MOS doctrine + capability tags → cluster into “regions”.
  - Activate top‑R regions by mean S(i); pick top‑K per region with diversity penalty; always include policy must‑include shops.

Explainability & Evidence
- Coordinator checkpoint lists: selected agents, scores (S breakdown), matched doctrine tags, must‑include coverage.
- Specialist checkpoints include: similarity score, citations (docId/section/quote) to doctrine/refs, and readiness/load inputs.
- Aggregator checkpoint shows: consensus method, dissent summary, and evidence links.
- “Handshake strength” metric per checkpoint (0–1):
  - Coverage (claims with citations) 0.4; Corroboration (unique sources/claim) 0.2; Specificity (direct quotes/sections) 0.2; Compliance (classification/ROE conformance) 0.2.
  - Enforce minimum threshold (e.g., 0.6) or route to a Judge sub‑step to improve.

Context Budgets (Practical Limits)
- Mission seed ≤300 tokens (intent + endstate + constraints + acceptance criteria + CCIR).
- Doctrine snippets: top 3–5 passages per specialist (≈300–800 tokens total).
- Specialist output: bounded schema (≤120‑word summary, 2–3 bullets, evidence ids/quotes).
- Aggregation: structured merge (≤400–600 tokens). Keep all prompts/summaries bounded.

Compute, Cost, and Rate Limits
- Precompute and cache doctrine embeddings: per MOS/billet centroid vectors (CoreData). Refresh/version as docs change.
- Per run: 1 mission embedding + small tag embeddings.
- K caps: Org (top 1–2 per shop), Mesh (top 2–3 per active region, overall K≈6–8) plus must‑include shops.
- Throttling: concurrency caps and jitter to respect OpenAI rate limits; retries with backoff.
- Offline/D‑DIL: use cached vectors; fallback to policy/chain-only selection if embeddings unavailable.

UI Recommendations
- Mission Input: add Flow picker [Let ARCnet choose (default), Pure Org, Mesh (Crowd), Hybrid].
- “Assist Me” triggers FlowAdvisor; shows a FlowAdvice checkpoint (chosen mode, scores, clarifications) for approval.
- Inline clarifiers for Intent, Endstate, Constraints, Acceptance Criteria; highlight missing fields.
- Region heatmap overlay (optional) in Mesh mode; otherwise a list with scores and policy flags.

Engine Recommendations
- FlowMode & Weights
  - Add `FlowMode { assist, org, mesh, hybrid }` and optional `FlowWeights { w_chain, w_sim, w_policy, w_ready, w_load }`.
  - `runMission(_ mission, mode: FlowMode, weights: FlowWeights? = nil)` in StageOrchestrator.
- Router (Coordinator)
  - Compute embeddings, scores, apply must‑include coverage, diversity penalty, K caps.
  - Emit Coordinator checkpoint with selection rationale.
- Aggregator (Mesh/Hybrid)
  - Merge specialist outputs with a transparent rubric; compute handshake metrics; flag dissent.
- Persistence & Audit
  - Store selection scores, vectors’ versions, region assignments, handshake metrics in CoreData; append JSONL logs.

Data Model Additions
- DoctrineVector { mosCode, docId, vector, version } and/or { billetId, vector, version }.
- CapabilityTag { id, name, vector } derived from METL/task taxonomy.
- Extend repositories: DoctrineRepository.docsForMOS, vectorsForMOS; OrgRepository.getRoster; FeedRepository readiness/load.

Evaluation Plan (A/B)
- Scenarios: status‑only, status+planning (TEEP constraint), ISR‑heavy, logistics‑heavy, readiness recovery.
- Metrics: time‑to‑decision, token usage, commander satisfaction, quality (rubric), handshake score, dissent surfaced.
- Compare Org vs Mesh vs Hybrid with matched token budgets; collect overrides/edits to learn weights.

Risks & Mitigations
- Compliance/accountability: keep gates, coverage rules, classification filters; log rationale.
- Token/cost blowups: bound context; cap K; use light→heavy multi‑pass (Draft→Judge→Finalize).
- Bias/echo chambers: impose diversity penalties; require dissent capture; ensure policy must‑include coverage.
- Stale vectors: version doctrine embeddings; refresh on pack updates.
- Rate limits: throttle queues; backoff; cache results for similar missions.

Roadmap & Improvements
- Adaptive weights: learn from commander overrides (bandit or Bayesian updates) while preserving guardrails.
- Dynamic K: scale number of specialists by mission complexity and confidence.
- Cross‑run caching: reuse prior drafts/options when missions are similar; show diffs under new constraints.
- Human control: expose a simple “emphasize chain” ↔ “emphasize specialty similarity” dial (bounds w_chain vs w_sim within a safe range).

Open Questions
- Governance: who curates MOS→doctrine mappings and capability tags; how often do we refresh embeddings?
- Policy: what are “must‑include” defaults by mission type/gate; how do we express them (e.g., gate_policy.v1.json)?
- UI: do we need the org canvas to visualize regions, or is a list sufficient in Mesh mode?
- Security: classification filters on doctrine snippets in prompts; redaction requirements in outputs.

Implementation Note
- Do not scaffold code yet. Treat this document as a design input; when approved, implement in small, reversible steps gated behind a feature flag (e.g., CROWD_MODE) and backed by unit tests and scenario A/B runs.

