# Canonical Overview — ARCnet iPad App (SwiftUI)
**Version 1.2 — Agentic Decision Flow & Commander-in-Control Spec**

---

## 1. Purpose
Project ARCnet for iPad provides a **mission-driven, decision system** that mirrors the commander’s staff process in digital form.  

ARCnet creates a Command Digital Twin — a full digital mirror of the commander’s organization. This twin synchronizes live data (Operations, personnel, logistics, intelligence, and finance) with AI reasoning agents that represent every billet from the MEF down to the platoon level.


The app enables a commander to:

1. Define a mission in plain language.  (Mission statement, Commanders intent, Endstate, Contstraints)
2. Watch the staff’s AI agents and sub agents reason through every phase transparently.  
3. Interact, approve, or adjust at each stage.  
4. Maintain complete control — the system always pauses for approval by default.

---

Note on Workflows
- The iPad app ships with its own in‑app agentic workflow powered by an LLM API key. It does not execute any CLI.

Canonical Overview & Guardrails
- This file is the canonical overview of the ARCnet app. If any other document conflicts with this, this file governs product intent and scope.
- Runtime Single Source of Truth (SSOT): CoreData is the authoritative store for app state. All inputs (USMC Org Pack, synthetic metrics, LLM outputs) are first materialized into CoreData before UI consumption.
- Organizational Data Source (not synthetic): The USMC org structure is imported from `Ref-Packs/USMC_Org_Pack/Services/org_templates/*.json` on first run. Users select “My Unit” to scope the app to their unit and subtree.
- MVP Constraints: No enterprise connectors and no MCP/tool‑calling in MVP. Only the LLM is permitted to use network.
- LLM Defaults & Keys: Default model is `gpt-5`. The OpenAI API key is stored in Keychain and can be switched at runtime. An OpenAI key is required; no mock fallback is used.
- Visual Policy: Do not color‑code by G‑shop. Use a neutral palette; reserve color for autonomy/status indicators (HITL/HOTL/Autonomous) with accessible contrast.


## 2. Technical Stack

| Layer | Technology | Purpose |
|-------|-------------|----------|
| **Language** | Swift 6 | Native concurrency, modern async flow |
| **UI Framework** | SwiftUI 3 + Combine | Declarative tablet interface |
| **Visualization** | SceneKit + Swift Charts | Org tree & decision-path animation |
| **Data Layer** | CoreData + CloudKit | Offline / D-DIL storage |
| **Networking** | URLSession + WebSockets | Agent messaging & real-time updates |
| **Security** | Keychain + CryptoKit | Secure key/MCP storage |
| **Architecture** | MVVM + Coordinator | Clear separation & navigation flow |

---

## 3. Layout Overview (Landscape Default)

```
┌──────────────────────────────────────────────────────────────┐
│ Top Bar : [☰ Menu] | [Unit Selector] | [📊 Dashboard] | [⚙ Integrations] │
├──────────────────────────────────────────────────────────────┤
│ Sidebar (Collapsible)           │ Main Canvas (Org Tree)      │
│ ─ Unit Library                  │ - Interactive hierarchy     │
│ ─ Agent Library (+Add Agent)    │ - Decision flow animation   │
│ ─ Recent Decisions              │ - Tap node → Detail Sheet   │
│ ─ API / MCP Keys Manager ⚙️     │                              │
├──────────────────────────────────────────────────────────────┤
│ Expandable Bottom Sheet : Decision Timeline / Logs / Widgets │
└──────────────────────────────────────────────────────────────┘
```

- **Landscape:** default; shows full org tree and dashboard toggle.  
- **Portrait:** collapses sidebar; introduces radial “Command Wheel” for quick actions.

---

## 3.1 Commander UI (Core Screens)

- Dashboard: customizable tiles (e.g., Funds Control, Maint Readiness, Net Health). Layout saved per commander.
- Org Chart: customizable graph of the commander’s organization including all G‑shops or S‑shops and their staffs, structured along the org tree. Boxes represent either a Marine billet (individual) or a shop (section); each box is backed by an agent. Lines include inline nodes (compiler, judge, tournament) and animate to reflect activity states (research, compile, judge, tournament).
- Tap any box/line to open a standardized Print panel 

- Tasking & Orders: outputs of approved COAs; tabs for Tasks / Orders Doc / Timeline. Data contract: `ui.tasking_orders.v1` (see `docs/ui/tasking_orders_screen.md`).

### Unit Selector (First‑Launch)
- On first run, the commander selects “My Unit” from the preloaded USMC organizational templates (MEF → Division/MAW/MLG → subordinate units).
- The app instantiates the selected unit’s subtree (marked `approximate` where applicable) and sets it as the default scope for the Org Tree and Dashboard.
- Provenance from the org template (doctrinal sources) is preserved and viewable in the Inspector.

### Autonomy Modes (Per Agent)

Commander can toggle between modes
- HITL (default) → no auto‑advance; HOTL → auto‑advance with intervention possible; Autonomous → proceed without prompts. Mode is visible on the box badge and in the Print header.

---

## 4. Commander Dashboard (Customizable C2 Board)

### 4.1 Purpose
A personalized **Critical Information List (CIL)** board where commanders can pin real-time operational widgets.

### 4.2 Behavior
- Tap 📊 **Dashboard** → opens grid of active widgets.  
- Tap “＋ Add Widget” → opens searchable **Widget Library**.  
- Browse or search (Maintenance / Funding / Logistics / ISR / Readiness etc.).  
- Tap widget → added to grid; drag to rearrange or resize.  
- Layout saved in CoreData (`WidgetConfig`).

### 4.3 Example Widgets

| Widget | Description | Data Source |
|---------|--------------|-------------|
| **Maintenance Readiness** | Platform readiness % | `g4.maint_forecast.v1` |
| **Funding Burn Rate** | G-8 funds control visualization | `g8.funds_control.v1` |
| **TEEP Schedule** | Training & exercise timeline | `g7.training_event.v1` |
| **ISR Feed Status** | Active UAV/SIGINT feeds | `g2.intel_summary.v1` |
| **Blue Force Tracker** | Friendly positions map | BFT API (sim / live) |
| **Comm Health** | Net health / EMCON | `c2.net_status.v2` |
| **Weather (METOC)** | Tactical forecast | WX API |

### 4.4 Widget Feeds (G/S‑Shop Agents)
- The commander’s dashboard is widget‑based and fully customizable. Widgets are fed by the outputs of staff (G‑ or S‑shop) agents aligned to their domains (e.g., G‑3/5 for TEEP events, G‑8 for funds, G‑4 for maintenance/readiness, G‑6 for comms).
- In MVP, widgets are fed from synthetic data via agents; in future builds, specialist agents may draw live data via approved APIs or MCP tools.

---

## 5. In app Agentic Decision Flow

This is the **core workflow** — every stage produces visible checkpoints and pauses for commander input by default.

### 5.0 Agent Seeding & Context

Each agent is seeded with a common operational context and doctrine before acting:
- Commander’s inputs: mission statement, commander’s intent, end state, constraints, and acceptance criteria.
- Doctrinal/training references (MOS‑scoped): only agents whose billet MOS matches a T&R/METL mapping are pre‑seeded with those manuals. MOS‑agnostic stages (e.g., Scribe, Coordinator, Integrator, Evaluator) use general staff guidance only.
- Mission/task context: unit selection ("My Unit"), echelon, and current operational posture.

Roster and distribution are determined strictly by the selected organization (unit + subtree). The app instantiates agents for the billets that exist in the imported org structure—no extra MOS agents are created outside that roster.

### Flow Overview


|--:|--------|-------------|------------------|
| 1 | **Mission Input** | User (Commander) | Enters plain-language mission statement, acceptance criteria, end state, and constraints. |

| 2 | Scribe Agent | Polishes mission and offers 1–2 improvement suggestions; commander selects one or keeps the original. |

| 3 | Coordinator | Coordinates across G‑/S‑shops and assigns specialist agents (by MOS/section); displays the staff tasking map. |

| 4 | Specialist Agents | Research and pull relevant data (MVP: synthetic data feeds; Future: approved APIs/MCP). Output short, referenced summaries. |

| 5 |Integration Agent | Merges findings, weighs data by mission type and desired end state, and generates an integrated picture. |

| 6  Evaluation Agent | Assesses complexity and recommends whether a COA tournament is needed. Commander approves or bypasses. |

| 7 | COA Agents | Generates COAs, compares them transparently, and presents scoring with rationale. |

| 8 | **Approval Gate** | System Prompt | Commander reviews winning COA summary, scorecard, and assumptions; Approve / Modify / Reject. |

| 9 | Tasking Agent | Outlines tasking, sequencing, and resource implications for impacted units. |
| 10 | **Final Approval / Implementation** | Commander & Orchestrator | Commander approves final plan; execution verification begins. |

### 5.1 UI Representation
- **Decision Path Line** glows through org tree as agents activate.  
- **Checkpoint Dots** = tappable; open **Checkpoint Cards**.  
- **Pause Points:** Default after every stage (Commander must approve).  
- **Auto-Advance Mode:** Optional; can be toggled per stage.  
- **Checkpoint Card:** Displays agent name, rationale, evidence, confidence, dissent, and logs.

---

## 6. Org Tree Canvas

- Built with SceneKit for zoom/pan performance.  
- Nodes = billets (individual Marines), shops/sections (G‑/S‑shops), and their backing agents.  
- **Gestures:** Tap → Inspector; Long-Press → Drag/Drop; Pinch → Zoom.  
- Neutral palette; reserve color for autonomy/status only (Green = HITL / Yellow = HOTL / Red = Autonomous).  
- “Run Mission” button appears when structure ready.

### 6.1 Information Flow (Chain of Command)
- Specialist agent findings flow up through their parent sections and echelons (e.g., section → shop → unit) and are integrated at higher levels by the Integrator and Evaluator agents before COA comparison and decision.

---

## 7. Inspector Panel (Slide-Over Sheet)

| Tab | Contents |
|-----|-----------|
| **Overview** | Billet, MOS, echelon, parent unit |
| **Agents** | List, autonomy mode, confidence, performance |
| **Logs / Checkpoints** | Full timeline and reasoning path |
| **COA Tournament** | Scoring matrix and ranking visualization |
| **Policies / Guardrails** | ROE, classification limits, risk controls |
| **Integrations** | OpenAI key (MVP); future endpoints reserved |

---

## 8. Integrations Manager (API & MCP Keys)

### Access
- Tap ⚙ → “Integrations & Keys.”

### Fields (MVP behavior: only OpenAI key is used; others are reserved)

| Field | Example | Notes |
|--------|----------|-------|
| OpenAI Key | `sk-...` | Used by reasoning agents (default model: `gpt-5`) |
| LLM Model | `gpt-5` | Switchable at runtime |
| (Reserved) Supabase URL | `https://project.supabase.co` | For future data connectors |
| (Reserved) Supabase Key | `SBP-XXXX` | Encrypted in Keychain |
| (Reserved) ISR Feed Token | `ISR-ABC123` | For future intel sources |
| (Reserved) MCP Endpoints | `[{"url":"https://mcp1","type":"intel"}]` | For future tool calling |

**Controls:**
- Test Connection (per endpoint).  
- Rotate Keys → regenerate credentials.  
- Biometric unlock required.  
- Stored in **Keychain (AES-256)**; never leaves device unencrypted.

Seed Status
- Inspector shows per-agent seed status: Mission Context received, Doctrinal Seeds linked, Connectors enabled/disabled.  
- Tap to view `mission_context.json` and linked doc sections from the Document Pack.  

---

## 9. Data Models (Swift)

```swift
struct MissionRun: Identifiable, Codable {
    var id: UUID
    var missionStatement: String
    var acceptanceCriteria: [String]
    var constraints: [String]
    var endState: String
    var checkpoints: [Checkpoint]
}

struct Checkpoint: Identifiable, Codable {
    var id: UUID
    var stage: String
    var agent: String
    var summary: String
    var confidence: Double
    var timestamp: Date
    var requiresApproval: Bool
    // MCPP alignment
    var mcppPhase: String // problem_framing | coa_dev | wargame | comparison | decision | orders
    var gate: String // A | B | C | D | none
    // CCIR tags
    var ccir: CCIR?
    // Classification and provenance
    var classification: String
    var caveats: String?
    var relTo: String?
    var evidence: [Evidence]
}

struct CCIR: Codable {
    var pir: [String]
    var ffir: [String]
    var eefi: [String]
}

struct Evidence: Codable {
    var docId: String
    var section: String?
    var quote: String?
}

struct DashboardWidget: Identifiable, Codable {
    var id: UUID
    var name: String
    var dataSource: String
    var refreshInterval: TimeInterval
    var position: CGPoint
    var size: WidgetSize
}

// Mission Context seed used across agents
struct MissionContext: Codable {
    var intent: String
    var endState: String
    var constraints: [String]
    var acceptanceCriteria: [String]
    var ccir: CCIR?
}
```

---

## 10. Logging & Explainability

- Each stage produces an `audit.log_entry.v1` with `mcpp_phase`, `gate`, and classification fields.  
- Logs grouped per mission run ID.  
- Commander can tap any checkpoint → inspect inputs, outputs, and reasoning chain.  
- Exportable as JSONL, PDF, or DOCX (Decision Paper).

---

## 11. Offline / D-DIL Mode

- Caches T/O&E, agents, and dashboards locally.  
- Auto-sync when back online.  
- Connection Status Dot: 🟢 Online | 🟡 Degraded | 🔴 Offline.

---

## 12. MCPP Mapping in UI

- Decision Path shows current MCPP phase label beneath the stage name.
- Gate badges (A/B/C/D) appear at pause points; tapping reveals the rationale and approval history.
- Inspector → Policies tab shows the active autonomy mode per agent and the MCPP decision point that governs advancement.

---

## 12. Security Architecture

- **Keychain + CryptoKit** → credential storage.  
- **TLS 1.3** → encrypted communication.  
- **AES-256** → encrypted data at rest.  
- **MDM enforcement** for DoD device compliance.

---

## 13. Export & Reporting

- **Mission Summary Report (PDF)** with checkpoint logs.  
- **FRAGO / Decision Paper / WARNORD (DOCX)** formatted templates.  
- **Dashboard Snapshot (PDF)** appended as Annex.  
- **JSON Export** for analytics and AAR ingestion.

---

## 14. Accessibility / Touch Design

- Fully supports Dynamic Type and VoiceOver.  
- High-contrast color palette + large touch zones.  
- Pencil support for annotating org tree or flow diagrams.  
- Haptics on approval / completion / errors.

---

## 15. Developer Checklist

✅ Target: iPadOS 18+ (ARM64).  
✅ Swift Concurrency verified.  
✅ CoreData encryption validated.  
✅ Gesture + decision flow UI tests completed.  
✅ Security & MDM compliance certified.

---

## MEF Major Subordinate Commands (MSCs)
- A Marine Expeditionary Force (MEF) consists of three major subordinate commands that form the MAGTF:
  - Division → Ground Combat Element (GCE)
  - Marine Aircraft Wing (MAW) → Aviation Combat Element (ACE)
  - Marine Logistics Group (MLG) → Logistics Combat Element (LCE)
- Marine Expeditionary Units (MEUs) are composited from subordinate units of the parent Division (GCE), MAW (ACE), and MLG (LCE):
  - BLT (from Division), Composite Squadron (from MAW), and CLB (from MLG), plus a Command Element.
