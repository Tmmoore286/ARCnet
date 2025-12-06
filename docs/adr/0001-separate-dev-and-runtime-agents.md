# ADR 0001 — Separate Dev Agents from In‑App Agents

Status: Accepted
Date: 2025-10-21

Context
- We will use an agentic development workflow to build the app. The app itself also implements an in‑app agentic decision system. These must not be conflated.

Decision
- Create and enforce a strict separation:
  - Dev agents and automation live under `dev/agent-workflow/` and are excluded from all Xcode targets.
  - Runtime agents live under `App/Agents/` and ship with the app.
  - Use prefix `DEV::` when referring to development agents; reserve “Agent” for in‑app runtime code.
- Document the separation in CODEX.md §2.1 and AGENTS.md.

Consequences
- Prevents shipping dev tooling in release binaries.
- Avoids user confusion and architectural drift.
- Provides a consistent collaboration pattern for humans and dev agents.

