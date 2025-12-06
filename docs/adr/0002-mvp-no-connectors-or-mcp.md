# ADR 0002 — MVP: No Connectors or MCP

Status: Accepted
Date: 2025-10-21

Context
- MVP must run without enterprise connectors. Dynamic metrics use synthetic data feeds when connectors are disabled. Future data sources include DRRS, GCSS‑MC, DAI, MCTFS, etc., and MCP tooling may be added later.

Decision
- Do not enable any enterprise connectors or MCP tool‑calling in MVP.
- Provide extension points and feature flags (`NO_CONNECTORS`, `USE_SYNTHETIC_FEEDS`).
- Allow only OpenAI network calls for reasoning (OpenAI key required).

Consequences
- Predictable, offline‑capable synthetic mode for dynamic data feeds; reduced risk and compliance scope.
- Architectural seams exist for future integration with minimal refactor.
