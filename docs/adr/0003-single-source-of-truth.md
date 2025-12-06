# ADR 0003 — Single Source of Truth (SSOT)

Status: Accepted
Date: 2025-10-21

Context
- The app must present consistent, auditable state across views while using multiple inputs: USMC Org Pack (authoritative), synthetic data feeds (when connectors are disabled), commander inputs and doctrinal references, and LLM outputs.

Decision
- CoreData is the single source of truth (SSOT) for runtime state.
- USMC Org Pack templates are imported on first run and persisted as the authoritative org baseline; UI never reads org JSON directly.
- Dynamic metrics are ingested from synthetic JSON feeds (when connectors are disabled) but persisted into CoreData before display.
- LLM outputs are materialized as `Checkpoint`s and saved in CoreData before being rendered; logs append with references to SSOT IDs.
- Repositories (`OrgRepository`, `MissionRepository`, `WidgetRepository`) mediate all read/write access to CoreData. Views/ViewModels depend only on repositories.
- Secrets live in Keychain (outside SSOT). Log files are append‑only artifacts referencing SSOT, not a parallel truth.

Consequences
- Predictable, debuggable state; no UI driven directly by files/network.
- Importers (`USMCOrgImporter`, `FeedImporter`) become change gates; versioned imports enable controlled updates.
- Swapping data sources (e.g., connectors later) does not affect UI, only repositories/importers.
