# Appendix B — Data Source Inventory (Unclassified)

Owners
- G‑3: operations/training schedules (TEEP), commander guidance.
- G‑4: maintenance status/logs, platform availability, backlog.
- G‑8: historical budgets, status of funds, future budgets.

Inventory (sample)
- Readiness Snapshot
  - Fields: platform, availability %, training proficiency, last update
  - Refresh: weekly/monthly
  - Access: G‑3/G‑4 export; unclassified aggregate
- Maintenance Logs
  - Fields: platform, downtime category, start/end, parts, notes
  - Refresh: weekly; aggregate only
  - Access: G‑4 export; redact free‑text as needed
- Funds Status
  - Fields: appropriation, line, planned, executed, remaining, constraints
  - Refresh: weekly/monthly
  - Access: G‑8 export; unclassified totals
- TEEP Schedule
  - Fields: event, date, unit, resource requirements, dependencies, no‑degrade flags
  - Refresh: as updated
  - Access: G‑3 export; unclassified extract

Controls
- Unclassified only; redact/remove PII or sensitive notes before ingestion.
- Versioned imports with provenance; least‑privilege access.

