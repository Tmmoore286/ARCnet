# ARCnet iPad App — CODEX

Version: 1.0 (MVP Scope)

This document orients developers to the ARCnet iPad app: what it is, how it’s structured, how to run it in synthetic mode (no connectors), and how to extend it later with APIs and MCPs without changing the core app.

Notice: The canonical product overview lives in `Canonical-OVERVIEW.md` at the repo root. If this file conflicts with that overview, `Canonical-OVERVIEW.md` governs.

Proposal (Needs Review)
- See `Flow-Mode-Proposal.md` for a draft concept introducing an optional Flow selector (Org, Mesh, Hybrid) and a FlowAdvisor. This is a draft only and is not part of the MVP until reviewed/approved.

> MVP constraint: No external enterprise data APIs or MCPs are used. The only allowed network is the OpenAI LLM provider. When connectors are disabled, agents consume synthetic data feeds stored locally on device.


## 1) Overview

ARCnet is a commander‑in‑control decision system that mirrors a staff’s workflow via transparent, agentic stages. It produces explainable checkpoints aligned to MCPP phases and approval gates, with Human‑in‑the‑Loop (HITL) by default.

MVP demonstrates:
- Mission → Scribe → Coordinator → Specialists → Integrator → Evaluator → COAs → Approval → Tasking flow
- Org tree canvas with animated decision path and checkpoint cards
- Commander dashboard with a few synthetic widgets
- Local audit logs and simple export


## 2) MVP Constraints

- No enterprise APIs (DRRS, GCSS‑MC, DAI, MCTFS, etc.) in MVP. Synthetic data feeds only when connectors are disabled.
- No MCP/tooling integrations active in the app. Extension points are stubbed and documented.
- The only network call permitted is the OpenAI LLM provider.
- All data stored locally via CoreData; synthetic feeds bundled as JSON for offline use.
- Security posture: Keychain for secrets; TLS 1.3 for the OpenAI client; at‑rest AES‑256 for sensitive local blobs.

### 2.1 Agentic Development vs In‑App Agents (Do Not Confuse)

You can use an agentic workflow to build/maintain this repo, but it is completely separate from the app’s runtime agents.

- Scope: Development agents (like Codex CLI) run outside the app and never ship in the iOS binary.
- Separation: All dev‑automation lives under `dev/` (or `.codex/`) and is excluded from Xcode targets.
- Naming: Use the term “Dev Agent” (prefix `DEV::`) for build automation. Reserve “Agent” for in‑app types under `App/Agents/`.
- Logging: Dev agent plans/logs stay in `dev/agent-workflow/` and must not be written into `App/`.
- Governance: All dev‑agent changes are human‑reviewed; no automatic merges to `App/` without approval.

Dev agent scaffolding (non‑shipping):

```
dev/
└─ agent-workflow/
   ├─ README.md                 purpose and usage
   ├─ playbooks/                task recipes (markdown)
   ├─ plans/                    incremental plans/state (json)
   ├─ prompts/                  reusable prompts for dev automation
   └─ scripts/                  helper scripts (no network keys)

.gitignore → ensure dev outputs don’t pollute `App/` or Xcode builds
Xcode Target Membership → exclude `dev/` from all app targets
```

### 2.2 Single Source of Truth (SSOT)

- SSOT store: CoreData is the single, authoritative store for runtime app state.
- Org structure: Imported from USMC Org Pack (`Ref-Packs/USMC_Org_Pack/Services/org_templates/*.json`) on first run via an importer, then owned by CoreData. Not synthetic.
- Commander inputs (MissionContext) and doctrinal references (T&R and curated docs) are seeded to agents by billet/MOS and persisted/linked prior to use. Not synthetic.
- Dynamic metrics (MVP): Ingested from synthetic JSON feeds when connectors are disabled, then written into CoreData before any UI consumption.
- LLM outputs: Become `Checkpoint`s and are persisted to CoreData (and appended to JSONL logs) before UI renders.
- UI rule: Views/ViewModels read state only through repositories backed by CoreData; no direct reads from files/network/LLM.
- Keys and secrets are not part of SSOT (they live in Keychain). Logs are append‑only and reference SSOT IDs.

### 2.3 MOS‑Scoped Doctrine Seeding

- Doctrine linking is MOS‑scoped: only agents whose billet MOS matches a curated mapping receive MOS‑specific Training & Readiness (T&R) manuals and METLs.
- MOS‑agnostic stages (e.g., Scribe, Coordinator, Integrator, Evaluator) use general staff guidance and policy, not MOS‑specific doctrine.
- Agent roster and distribution derive strictly from the selected organization (unit + subtree) imported from the USMC Org Pack; the system does not create extra MOS agents outside that roster.


## 3) High‑Level Architecture

- Language/Frameworks: Swift 6, SwiftUI + Combine, SceneKit, Swift Charts
- App Architecture: MVVM + Coordinator
- Orchestration: StageOrchestrator coordinates agent stages and approval gates
- Data: CoreData + bundled JSON feeds; abstractions for future connectors
- LLM: LLMClient abstraction with OpenAI implementation (key required)
- Security: KeychainService for API keys; no secrets in UserDefaults or code

### 3.2 LLM Defaults & Keys

- Default provider: OpenAI; default model: `gpt-5`.
- Keys: Users set the OpenAI API key in the Integrations screen (stored in Keychain). The `LLMClient` reads the active key at runtime; key is required to run agents.
- Extensibility: `LLMConfig` includes `model`, `apiKey`, and optional `baseURL` to enable future provider swap without changing call sites.


### 3.1 Core Abstractions

```swift
// Agents drive each stage of the decision flow.
public protocol Agent {
    var id: String { get }
    var name: String { get }
    func run(input: AgentInput, context: MissionContext, llm: LLMClient) async throws -> AgentOutput
}

public struct AgentInput: Sendable, Codable { /* stage-specific fields */ }
public struct AgentOutput: Sendable, Codable { /* summary, evidence, confidence */ }

// Orchestrates stages, autonomy, and checkpoints.
public protocol StageOrchestrating {
    func runMission(_ mission: MissionRun) async throws -> AsyncStream<Checkpoint>
}

// LLM abstraction for provider independence.
public protocol LLMClient {
    func complete(messages: [LLMMessage], config: LLMConfig) async throws -> LLMResponse
}

// Data abstraction for synthetic feeds now and connectors later.
public protocol DataGateway {
    func readinessSnapshot(for unitId: String) async throws -> Readiness
    func fundsSnapshot(for unitId: String) async throws -> Funds
    // etc.
}

// Optional future connector shape (unused in MVP runtime).
public protocol Connector {
    var id: String { get }
    var capabilities: [Capability] { get }
    func testConnection() async -> Bool
}
```


## 4) Directory Layout (Proposed)

The repo currently includes reference packs under `Ref-Packs/`. App code will live alongside in an `App/` directory.

```
App/
  ARCnetApp.swift                 // App entry
  AppConfig.xcconfig              // Build flags (USE_SYNTHETIC_FEEDS, NO_CONNECTORS)
  Domain/
    Models.swift                  // MissionRun, Checkpoint, CCIR, Evidence, etc.
    Mappings.swift                // MCPP + gate labels
  Engine/
    StageOrchestrator.swift       // Coordinates stages + HITL/HOTL/Auto
    Autonomy.swift                // Autonomy modes + gate logic
    AuditLog.swift                // JSONL writer
  Agents/
    AgentKernel.swift             // Agent protocol & utilities
    Stages/                       // ScribeAgent, CoordinatorAgent, etc.
    Prompts/                      // Prompt templates (markdown)
  LLM/
    LLMTypes.swift                // Shared types/protocols
    OpenAIClient.swift            // OpenAI network client (key required)
  Data/
    SyntheticDataGateway.swift    // Reads bundled JSON feeds
    FeedImporter.swift            // Ingests feeds into CoreData
    Schemas.swift                 // DTOs for feeds
    SyntheticData/                // *.json synthetic feeds
  UI/
    Dashboard/                    // Widgets, library, grid
    OrgTree/                      // SceneKit canvas
    Inspector/                    // Slide-over, tabs
    MissionInput/                 // Mission form + review
    Timeline/                     // Checkpoints, logs
    Integrations/                 // OpenAI key (MVP only)
  Security/
    KeychainService.swift         // API key storage
  Exports/
    PDFExporter.swift             // Mission summary (basic)
    JSONLWriter.swift             // Log export
  Support/
    PreviewContent/               // SwiftUI previews
    AppIcons/

Ref-Packs/                        // Reference schemas and examples (already present)
```

### 4.1 Scaffolding ASCII Map

End-to-end scaffold at a glance — what to create first and how pieces connect. Brackets denote role: [view], [vm], [engine], [agent], [data], [llm], [sec], [export], [flag].

```
App/
├─ ARCnetApp.swift                                   [app]  → boot, DI, feature flags
├─ AppConfig.xcconfig                                [flag] USE_SYNTHETIC_FEEDS=1, NO_CONNECTORS=1
├─ Domain/                                           [domain]
│  ├─ Models.swift                                   MissionRun, Checkpoint, CCIR, Evidence, MissionContext
│  └─ Mappings.swift                                 MCPP phases, Gate labels
├─ Engine/                                           [engine]
│  ├─ StageOrchestrator.swift                        runs stages, emits Checkpoints, enforces autonomy
│  ├─ Autonomy.swift                                 HITL/HOTL/Auto policies + gates
│  └─ AuditLog.swift                                 JSONL appender per MissionRun
├─ Agents/                                           [agent]
│  ├─ AgentKernel.swift                              Agent protocol, helpers
│  ├─ Stages/
│  │  ├─ ScribeAgent.swift                           polish mission
│  │  ├─ CoordinatorAgent.swift                      fan-out to shops
│  │  ├─ SpecialistAgent.swift                       gather refs (synthetic)
│  │  ├─ IntegratorAgent.swift                       merge findings
│  │  ├─ EvaluatorAgent.swift                        complexity, tournament needed?
│  │  ├─ COAAgent.swift                              generate/score COAs
│  │  └─ TaskingAgent.swift                          outline tasks/sequencing
│  └─ Prompts/
│     ├─ scribe.md                                   structured prompt
│     ├─ coordinator.md
│     ├─ specialist.md
│     ├─ integrator.md
│     ├─ evaluator.md
│     ├─ coa.md
│     └─ tasking.md
├─ LLM/                                              [llm]
│  ├─ LLMTypes.swift                                   shared types/protocols
│  └─ OpenAIClient.swift                               OpenAI network client (key required)
├─ Data/                                             [data]
│  ├─ SyntheticDataGateway.swift                      Readiness/Funds/NetHealth from bundled JSON feeds
│  ├─ FeedImporter.swift                              ingest feeds → CoreData
│  ├─ USMCOrgImporter.swift                           import USMC Org Pack → CoreData (authoritative org baseline)
│  ├─ Schemas.swift                                   DTOs for feed JSON
│  └─ SyntheticData/
│     ├─ units.json                                  MEF/Div/MAW/MLG tree
│     ├─ readiness.json                               synthetic DRRS-like snapshots
│     ├─ funds.json                                   synthetic DAI-like
│     ├─ comms.json                                   synthetic net health
│     └─ missions.json                                canned example missions
├─ UI/
│  ├─ MissionInput/                                  [view/vm]
│  │  ├─ MissionInputView.swift                       capture mission statement
│  │  └─ MissionInputViewModel.swift                  start run via StageOrchestrator
│  ├─ Timeline/                                      [view/vm]
│  │  ├─ TimelineView.swift                           list of Checkpoints
│  │  └─ TimelineViewModel.swift
│  ├─ OrgTree/                                       [view]
│  │  ├─ OrgTreeView.swift                            SceneKit canvas + glow path
│  │  └─ OrgNodeView.swift
│  ├─ Inspector/                                     [view]
│  │  ├─ InspectorView.swift                          tabs: Overview, Agents, Logs, COA, Policies, Integrations
│  │  └─ CheckpointCardView.swift                     rationale, evidence, confidence
│  ├─ Dashboard/                                     [view/vm]
│  │  ├─ DashboardView.swift                          grid + add widget
│  │  ├─ WidgetLibraryView.swift
│  │  └─ Widgets/
│  │     ├─ ReadinessWidget.swift                     uses DataGateway
│  │     ├─ FundsWidget.swift
│  │     └─ NetHealthWidget.swift
│  └─ Integrations/                                  [view/vm]
│     ├─ IntegrationsView.swift                       OpenAI key only (MVP)
│     └─ IntegrationsViewModel.swift
├─ Security/
│  └─ KeychainService.swift                           [sec] store/retrieve API keys (biometric)
├─ Exports/
│  ├─ JSONLWriter.swift                               [export] audit log export
│  └─ PDFExporter.swift                                [export] mission summary
├─ Support/
│  ├─ PreviewContent/                                 SwiftUI previews
│  └─ AppIcons/
└─ Tests/
   ├─ EngineTests.swift                                Orchestrator + autonomy
   ├─ DataGatewayTests.swift                           feeds + gateway
   └─ UITests.swift                                    dashboard/org/inspector/integrations flows

Ref-Packs/                                            reference schemas and example packs
```

### 4.2 Schemes & Targets

- Target: `ARCnet` (single iOS app target for MVP).
- Schemes:
- `Local (Synthetic)` — sets `USE_SYNTHETIC_FEEDS=1`, `NO_CONNECTORS=1`.
  - `Release` — same safe defaults; enables production signing settings.
- The `dev/` directory is excluded from all targets.

### 4.3 Modules & DI

- Keep a single target; enforce module boundaries by directory: Domain, Engine, Agents, UI, Data, LLM, Security, Exports.
- Use initializer injection (no DI container). Compose dependencies in `ARCnetApp.swift` and pass down via ViewModels.
- Keep Agents pure (no singletons). Pass `LLMClient` and `DataGateway` explicitly from the orchestrator.
 - Repositories: `OrgRepository`, `MissionRepository`, `WidgetRepository` mediate read/write to CoreData (SSOT).

Runtime flow wiring (engine-level):

```
MissionInputView → StageOrchestrator
   └─[ScribeAgent] → [CoordinatorAgent] → [SpecialistAgent(s)] → [IntegratorAgent] → [EvaluatorAgent]
       → [COAAgent(s)] → [Approval Gate] → [TaskingAgent]
             │
             ├─ emit Checkpoint → TimelineView / Inspector (cards)
             ├─ write AuditLog → JSONLWriter / PDFExporter
             └─ HITL/HOTL/Auto enforced by Autonomy policies

LLM path: Agents → LLMClient → OpenAIClient (key required)
Data path: Widgets/Agents → DataGateway → SyntheticDataGateway (bundled JSON feeds)
```


## 5) Data Model (Canonical)

These mirror `Canonical-OVERVIEW.md` and are the app’s internal contract. UI, exports, and future connectors must map to these types.

```swift
public struct MissionRun: Identifiable, Codable {
    public var id: UUID
    public var missionStatement: String
    public var acceptanceCriteria: [String]
    public var constraints: [String]
    public var endState: String
    public var checkpoints: [Checkpoint]
}

public struct Checkpoint: Identifiable, Codable {
    public var id: UUID
    public var stage: String
    public var agent: String
    public var summary: String
    public var confidence: Double
    public var timestamp: Date
    public var requiresApproval: Bool
    public var mcppPhase: String  // problem_framing | coa_dev | wargame | comparison | decision | orders
    public var gate: String       // A | B | C | D | none
    public var ccir: CCIR?
    public var classification: String
    public var caveats: String?
    public var relTo: String?
    public var evidence: [Evidence]
}

public struct CCIR: Codable { public var pir: [String]; public var ffir: [String]; public var eefi: [String] }
public struct Evidence: Codable { public var docId: String; public var section: String?; public var quote: String? }

public struct MissionContext: Codable {
    public var intent: String
    public var endState: String
    public var constraints: [String]
    public var acceptanceCriteria: [String]
    public var ccir: CCIR?
}
```

### 5.1 Persistence Model (Core Data ERD)

```
MissionRunEntity (id: UUID, missionStatement, endState)
  ├─ acceptanceCriteria: Transformable<[String]>
  ├─ constraints: Transformable<[String]>
  └─ checkpoints: To‑Many → CheckpointEntity

CheckpointEntity (id: UUID, stage, agent, summary, confidence: Double, timestamp: Date,
                  requiresApproval: Bool, mcppPhase, gate, classification, caveats?, relTo?)
  └─ evidence: Transformable<[EvidenceDTO]>

WidgetConfigEntity (id: UUID, name, dataSource, refreshInterval: Double, positionX: Double,
                    positionY: Double, width: Double, height: Double)
```

Notes
- Use lightweight migrations; keep Transformable payloads Codable.
- Encrypt sensitive blobs at rest where applicable.


## 6) Decision Flow & Autonomy

- Flow stages: Mission Input → Scribe → Coordinator → Specialists → Integrator → Evaluator → COAs → Approval Gate → Tasking → Final Approval
- Every stage emits a `Checkpoint`; each `Checkpoint` is tappable in UI and exportable.
- Autonomy modes (per agent):
  - HITL (default) — pause and require approval
  - HOTL — auto‑advance with the ability to intervene
  - Autonomous — proceed without prompts
- Orchestrator enforces mode and gate policy; UI indicates active mode and current MCPP phase.

### 6.1 Error Model

```swift
enum AppError: Error, LocalizedError {
    case agent(String)
    case llm(String)
    case data(String)
    case export(String)
    var errorDescription: String? { /* user-facing */ return nil }
}
```

- Surface errors via Checkpoint cards with clear actions (Retry, Edit Input, View Logs).
- Log errors with context but no secrets.


## 7) Extensibility Plan (APIs & MCP)

MVP ships without external data or MCPs, but the codebase is prepared to add them seamlessly:

- Data Connectors
  - Add a new `Connector` implementation (e.g., `DRRSConnector`, `GCSSMCConnector`, `DAIConnector`, `MCTFSConnector`).
  - Provide concrete repositories that conform to the `DataGateway` contract and map external schema → `Domain` models.
  - Register via a `ConnectorRegistry` (DI) for runtime selection and health checks.

- MCP Bridge
  - Introduce an `MCPBridge` with a message bus interface for tool calling.
  - Keep disabled in MVP behind `NO_CONNECTORS` flag; add lifecycle hooks in `StageOrchestrator` for tool availability checks.

- Integrations UI
  - MVP: OpenAI key entry only (Keychain). Later: add endpoints, tokens, per‑connector test buttons.


## 8) Security & Privacy

- Secrets: Store API keys in Keychain, viewable only after biometric unlock.
- Network: Allowlist OpenAI host; deny other outbound endpoints in Local (Synthetic) flavor.
- Data: Use AES‑256 encryption for at‑rest sensitive records; never persist raw prompts with unre­dacted PII.
- Logs: Include classification, caveats, and releasability in `Checkpoint`; redact on export when needed.
- MDM: Target compliance for managed iOS devices; avoid prohibited entitlements.

### 8.1 Specifics

- Keychain access group: app‑scoped; require biometric to view/rotate keys.
- Allowlist: Only OpenAI host in Local (Synthetic) scheme; consider compile‑time networking policy guards.
- Prompt redaction: mask tokens and sensitive input fields in logs/exports.


## 9) Build & Run (Synthetic Mode)

Prereqs:
- Xcode 16+ (Swift 6), iPadOS 18+ simulator or device (ARM64)

Steps:
1) Open the Xcode project/workspace once added under `App/`.
2) Select the `Local (Synthetic)` scheme (sets `USE_SYNTHETIC_FEEDS=1`, `NO_CONNECTORS=1`).
3) Run on an iPad simulator.
4) On first launch, open Integrations (⚙) to paste an OpenAI API key.

Notes:
- An OpenAI API key is required; only LLM calls use the network. All other dynamic data comes from synthetic feeds when connectors are disabled.

Schemes:
- `Local (Synthetic)` runs with default LLM model `gpt-5` unless overridden in Settings → Integrations.


## 10) Feature Flags

- `USE_SYNTHETIC_FEEDS` (default: true) — enables synthetic feeds and sample widgets when connectors are disabled.
- `NO_CONNECTORS` (default: true) — disables connectors and MCP bridge registration.

Recommended wiring: place in `AppConfig.xcconfig` and read via `ProcessInfo.processInfo.environment` or compile‑time flags.

### 10.1 Compile‑time vs Runtime Flags

- Compile‑time: Use `.xcconfig` for defaults (`USE_SYNTHETIC_FEEDS`, `NO_CONNECTORS`).
- Runtime: Allow in‑app toggles for developer previews (e.g., switch LLM model/key) stored in Keychain/UserDefaults as appropriate.


## 11) Synthetic Data Feeds

- Organizational structure: NOT synthetic. Imported from `Ref-Packs/USMC_Org_Pack/Services/org_templates/*.json` via `USMCOrgImporter` and stored in CoreData as the authoritative baseline. User selects “My Unit” to scope views.
- Commander inputs and doctrinal references: NOT synthetic. Agents are seeded with MissionContext and MOS/billet-appropriate references from Ref-Packs and linked into CoreData.
- Synthetic data feeds: `App/Data/SyntheticData/*.json` for readiness, funds, comms, intel summaries, and canned missions when connectors are disabled.
- Import: `FeedImporter` (dynamic feeds) and `USMCOrgImporter` (org structure) write to CoreData on first run or version change.
- Versioning: Include a schema version in each source; perform lightweight migrations when versions bump.


## 12) Logging & Exports

- All stages write `audit.log_entry` lines referencing `MissionRun.id`, `mcppPhase`, `gate`, classification, and evidence pointers.
- Exports: JSONL (raw), and a minimal PDF “Mission Summary” with checkpoint snapshots; DOCX templates can be added later.

### 12.1 Logging Contract

- JSONL keys per line: `runId`, `stage`, `agent`, `mcppPhase`, `gate`, `timestamp`, `classification`, `confidence`, `evidence[]`.
- Rotate log files by size/time; include app version and build in session header.

### 12.2 Prompt Guidelines

- Keep prompts concise with structured sections (Context, Task, Constraints, Output).
- Include classification headers and CCIR tags when relevant.
- Cap tokens to maintain responsiveness; prefer few‑shot examples using commander inputs and doctrinal references; include synthetic data feed exemplars only when relevant.


## 13) UI Overview

- Dashboard: grid of widgets; “＋ Add Widget” opens a local library backed by synthetic sources.
- Org Tree Canvas: SceneKit for zoom/pan; nodes are billets/agents; decision path glows; checkpoint dots open cards.
- Inspector: tabs for Overview, Agents (with autonomy), Logs/Checkpoints, COA Tournament, Policies/Guardrails, Integrations.
- Tasking & Orders: standardized view for approved COAs and sequence; based on `ui.tasking_orders.v1` contract.

### 13.1 Visual/Color Policy

- Do not color‑code by G‑shop.
- Use a neutral palette for billets/nodes.
- Reserve color for status and autonomy only (e.g., green HITL, yellow HOTL, red Autonomous indicators) and accessibility‑safe contrasts.


## 14) Concurrency & Performance

- Use Swift Concurrency (async/await). Keep all LLM/network on background tasks; update UI on main actor.
- Agents should be side‑effect free and pure where possible; use immutable inputs/outputs.
- SceneKit rendering on its own thread; throttle animations when the app is backgrounded.


## 15) Coding Conventions

- MVVM boundaries: Views → ViewModels → Engine/Agents → Data/LLM/Security.
- Naming: Prefer explicit names (`MissionRunViewModel`, `ScribeAgent`). Avoid one‑letter identifiers.
- Prompts: Store in `Agents/Prompts/*.md`. Keep short, structured, and reference doctrine as needed.
- Error handling: surfacing through `Checkpoint` with clear user‑actionable messages (Retry, View Logs, Modify Input).
- Accessibility: Support Dynamic Type, VoiceOver labels, large touch targets; high‑contrast palette.


## 16) Testing

- Unit tests: Orchestrator, autonomy logic, feed importer, DataGateway.
- Snapshot/UI tests: decision path, checkpoint cards, autonomy badge, Integrations key entry flow.
- LLM tests: prefer protocol-bound test doubles within `Tests/` (non-shipping). Do not commit real keys or call real network in tests.


## 17) How‑To: Add Things

### Add a New Dashboard Widget
1) Implement a `WidgetView` and `WidgetViewModel` sourcing from `DataGateway`.
2) Register the widget in the `WidgetLibrary` with an ID, name, and sample data mapping.
3) Add a seed data file if needed under `SyntheticData/`.

### Add a New Agent Stage
1) Create `Agents/Stages/<Name>Agent.swift` conforming to `Agent`.
2) Add prompt template under `Agents/Prompts/<name>.md`.
3) Register in `StageOrchestrator` stage list and set default autonomy mode.

### Add a New Connector (post‑MVP)
1) Create `<System>Connector` conforming to `Connector` and repositories that satisfy `DataGateway`.
2) Add Integrations fields (endpoint, token) and a “Test Connection” button.
3) Gate with `NO_CONNECTORS` flag until tested.

### Add MCP Tools (post‑MVP)
1) Implement `MCPBridge` and tool/provider descriptors.
2) Wire tool availability checks into `StageOrchestrator` as optional capabilities.
3) Keep disabled by default; expose a feature flag and per‑tool consent prompts.


## 18) Risks & Anti‑Goals (MVP)

- No live data ingestion; avoid partially built enterprise adapters.
- No on‑device model downloads or custom fine‑tunes.
- Avoid tight coupling of UI to external schemas; keep mapping via `DataGateway`.
- Keep synthetic mode stable and deterministic for feeds.


## 19) Glossary

- MCPP — Marine Corps Planning Process (phases: problem framing, COA development, wargaming, comparison, decision, orders)
- CCIR — Commander’s Critical Information Requirements (PIR, FFIR, EEFI)
- COA — Course of Action (candidate plans compared via a tournament/scorecard)
- HITL/HOTL — Human‑In‑The‑Loop/On‑The‑Loop autonomy modes
- MCP — Model Context Protocol (tool and multi‑agent coordination mechanism)


## 20) Roadmap Hints (Post‑MVP)

- Connectors: DRRS, GCSS‑MC, DAI, MCTFS — add read‑only adapters with robust RLS/tenancy controls.
- Secure Storage Alternatives: consider on‑prem enclaves when CloudKit is not available.
- Export Templates: FRAGO, Decision Paper, WARNORD (DOCX) with doctrine‑aligned styles.
- Analytics: JSON export ingestion for AAR; privacy‑preserving telemetry (opt‑in only).


---

Contact: Open an issue or leave notes in `Canonical-OVERVIEW.md` for updates to this CODEX.
