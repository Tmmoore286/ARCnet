# ARCnet MVP — Project Plan

Status: Draft (foundational, kept lean)

This plan captures scope, milestones, and acceptance criteria for the MVP build (Synthetic Mode for data feeds). It aligns with CODEX.md and AGENTS.md.

## Objectives
- Demonstrate a commander‑in‑control agentic decision flow with transparent checkpoints and HITL gating.
- Operate with an OpenAI key for reasoning; use synthetic data feeds for dynamic metrics when connectors are disabled.
- Keep architecture extensible for future enterprise connectors and MCP, but disabled in MVP.

## Scope
- In: Mission→Scribe→Coordinator→Specialists→Integrator→Evaluator→COAs→Approval→Tasking, Dashboard widgets (3), Org tree canvas, Inspector, Audit logs, JSONL/PDF export, Integrations (OpenAI key only), Unit Selector (import org from USMC Org Pack).
- Out (MVP): DRRS/GCSS‑MC/DAI/MCTFS connectors, MCP tool‑calling, multi‑tenant sync, live feeds, DOCX templates beyond minimal PDF.

## Milestones
- M0 Foundations (this stage)
  - Docs: CODEX.md, AGENTS.md, PLAN.md, initial ADRs
  - Definitions: feature flags, data contracts, autonomy policy
- M1 Domain & Engine
  - Models (MissionRun, Checkpoint, CCIR, Evidence, MissionContext)
  - StageOrchestrator + Autonomy policies + AuditLog (interfaces + stubs)
- LLMClient (OpenAI implementation)
- M2 UI Skeleton
  - MissionInput, Timeline (checkpoints), OrgTree (placeholder), Inspector (tabs), Integrations (OpenAI key)
  - Navigation + Coordinator wiring
- M3 Agents & Data
  - Scribe/Coordinator/Specialist/Integrator/Evaluator/COA/Tasking agents (prompt templates + stub outputs)
  - SyntheticDataGateway + FeedImporter; widgets (Readiness, Funds, Net Health)
- M4 Polish & Exports
  - PDF summary export, JSONL export, accessibility pass, basic UI tests

## Acceptance Criteria (Synthetic Mode)
- End‑to‑end mission run creates visible checkpoints per stage, with default HITL pauses and clear approvals.
- Org tree shows nodes and animated decision path; checkpoint cards open with rationale/evidence/confidence.
- Dashboard displays at least 3 widgets backed by synthetic data feeds.
- Integrations view stores/retrieves OpenAI API key in Keychain; agents require a valid key to run.
- Logs exportable as JSONL; basic Mission Summary PDF export works.
- No external enterprise calls; network restricted to OpenAI when enabled.
 - SSOT enforced: CoreData is the single source of truth. Org structure is imported from USMC Org Pack and owned by CoreData; UI and agents read via repositories only.
 - MOS‑scoped doctrine seeding: Only agents whose billets list matching MOS codes are pre‑seeded with T&R/METL doctrine; MOS‑agnostic stages use general guidance. Agent count and distribution derive solely from the selected unit roster (unit + subtree).

## Risks & Mitigations
- LLM latency → keep prompts concise; stream partial results where possible.
- Scope creep on connectors → locked by feature flag `NO_CONNECTORS=1` and documented non‑goals.
- SceneKit performance on lower devices → keep canvas minimal for MVP; defer heavy styling.

## Working Agreements
- Keep patches small and feature‑flagged; no runtime connectors/MCP in MVP.
- Use ADRs for consequential decisions; avoid silent architectural changes.
- Favor determinism in demos; avoid hidden network dependencies.
