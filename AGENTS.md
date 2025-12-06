# AGENTS.md — Guidelines for Human and Dev Agents

Scope: This file applies to the entire repository. Use it to guide agentic development workflows (e.g., Codex CLI or other automation) without confusing them with the in‑app agent system.

Note: The canonical product overview is `Canonical-OVERVIEW.md` at the repo root. Treat that file as the single source for product scope/intent.


## 1) Purpose & Ground Rules

- This repo contains an iPad app (ARCnet) that implements an in‑app agentic decision flow. Development agents used to build the app are separate and must never ship in the iOS binary.
- Follow CODEX.md for architecture, layout, and MVP constraints. Treat `Canonical-OVERVIEW.md` as the product concept.
- Keep changes minimal, focused, and reversible. Fix root causes; avoid broad refactors unless requested.


## 2) Terminology — Avoid Confusion

- In‑App “Agents”: Runtime components under `App/Agents/` that power commander workflows.
- Dev Agents: Any automation used during development (this CLI, scripts). When referring to dev automation, use the prefix `DEV::` (e.g., `DEV::Plan`, `DEV::Scaffold`).
- Do not put dev‑agent code under `App/`. Use `dev/` instead and exclude from Xcode targets.


## 3) Repository Layout Contracts

- See CODEX.md section “4) Directory Layout” and “4.1 Scaffolding ASCII Map”. Create new files in those locations unless instructed otherwise.
- MVP rules: No enterprise APIs or MCPs in runtime. When connectors/MCP are disabled, use synthetic data feeds. Agents always use the OpenAI client.
- Reserved paths:
  - `App/` — shipping app code only
  - `dev/agent-workflow/` — non‑shipping dev automation
  - `Ref-Packs/` — reference packs and schemas


## 4) Development Agent Workflow

- Planning: Maintain a short, up‑to‑date plan with clear, verifiable steps. Mark progress as steps complete.
- Preambles: Before running grouped actions/commands, post a brief note about what you’re doing next.
- File edits: Use small, targeted patches. Do not reformat unrelated files. Avoid renames unless necessary.
- Tests/validation: Prefer specific, fast checks for files you’ve changed. Avoid slow, broad test runs unless asked.
- Approvals/sandboxing: Assume restricted network and workspace‑write filesystem by default. Ask before destructive or networked actions.


## 5) Coding Conventions (App)

- Swift 6 + SwiftUI; MVVM + Coordinator; Swift Concurrency (async/await).
- Keep agents side‑effect‑free; pure inputs/outputs where possible.
- Prompts live under `App/Agents/Prompts/*.md`.
- Feature flags defined via `App/AppConfig.xcconfig` (`USE_SYNTHETIC_FEEDS`, `NO_CONNECTORS`).
- Security: No secrets in source. Use Keychain in runtime; never commit keys.


## 6) MVP Guardrails

- No enterprise connectors (DRRS, GCSS‑MC, DAI, MCTFS) in the app. Prepare extension points only.
- No MCP/tool calling at runtime. Keep any bridge stubs disabled behind `NO_CONNECTORS`.
- Synthetic data feeds only under `App/Data/SyntheticData/*.json` ingested by `FeedImporter`.
- The only permitted network at runtime is the OpenAI client (optional).

## 6.1 Single Source of Truth (SSOT)

- CoreData is the sole runtime source of truth. Dev agents must not wire UI directly to files, network responses, or in‑memory caches.
- Org structure must be imported from `Ref-Packs/USMC_Org_Pack/...` via an importer and persisted before use.
- Agents and sub‑agents are seeded with the Commander’s MissionContext (intent, endstate, constraints, acceptance criteria) and doctrinal references selected by billet/MOS. These inputs are not synthetic and must be persisted/linked before use.
- MOS‑scoped seeding: Only agents whose billet MOS matches a curated mapping are pre‑seeded with MOS‑specific T&R/METL doctrine. MOS‑agnostic stages use general staff guidance only.
- Roster source of truth: The number and distribution of MOS agents come strictly from the selected organization (unit + subtree) imported from the USMC Org Pack. Do not create agents for MOS not present in the roster.
- Dynamic synthetic feeds must be written into CoreData before views consume them. Treat files as inputs, not state.


## 7) Where To Add Things

- New widget: `App/UI/Dashboard/Widgets/` (+ library registration).
- New agent stage: `App/Agents/Stages/` (+ template in `App/Agents/Prompts/`). Wire in `StageOrchestrator`.
- New domain type: `App/Domain/Models.swift` (+ mappings if needed).
- New synthetic feed: `App/Data/SyntheticData/` (+ schema in `App/Data/Schemas.swift`).
- Dev automation: `dev/agent-workflow/` only.


## 8) PR/Handoff Expectations

- Summarize changes with a concise list of outcomes and rationale.
- Reference touched files explicitly (path with line anchors when relevant).
- Call out any follow‑ups, risks, or TODOs.
- Do not commit to VCS unless explicitly asked; provide patches/changes for review.


## 9) Security & Privacy

- Never commit secrets, tokens, or sample keys. Redact values in logs and prompts.
- Keep synthetic data free of real PII. Mark sample classification metadata clearly in feeds and outputs.
- Respect MDM/compliance posture described in CODEX.md. No prohibited entitlements.


## 10) Decision Authority

- If a direct instruction from a human owner conflicts with this file, follow the owner and note the deviation.
- If a conflict exists between CODEX.md and this file, prefer CODEX.md for architecture and runtime, and this file for development workflow.


## 11) Quick Checklist for Dev Agents

1. Read CODEX.md and Canonical-OVERVIEW.md first.
2. Create/Update a short plan; share before large edits.
3. Make minimal, scoped patches; avoid unrelated changes.
4. Keep MVP constraints: no connectors/MCP; synthetic data only.
5. Respect directory contracts; never place dev artifacts in `App/`.
6. Summarize results with file references and next steps.
