# Data Access Plan (Unclassified Only)

Data Owners and Roles
- G‑3: operations/training schedules, TEEP; commander’s guidance/constraints.
- G‑4: maintenance status, logs, backlog categories; readiness indicators by equipment/platform.
- G‑8: historical budgets, status of funds, fiscal plans; funding controls.

Data Sources (examples)
- Readiness snapshots: monthly/weekly rollups, platform availability, training proficiency.
- Maintenance: work orders/logs, parts availability, downtime categories, scheduled windows.
- Funding: OBM ledgers, execution status, constraints, projected lines.
- TEEP: events, dependencies, resource requirements, non‑degradation rules.

Access Pathway
- Confirm unclassified status for each feed and obtain written approval from data owners (email/MFR).
- Redact/remove PII or controlled info; prefer aggregates over raw line‑level data.
- Ingest into a segregated, unclassified SSOT store for the prototype; versioned imports.

Security & Compliance
- Unclassified only; no CUI/FOUO/PII. Apply redactions before ingestion.
- Classification metadata tracked on outputs (UNCLASSIFIED).
- Logs reference document IDs and SSOT records; no secrets in source or logs.

Availability & Continuity
- Prefer local exports or read‑only snapshots to avoid live system dependencies.
- If feeds are delayed, use synthetic/derived data to preserve schedule; mark provenance.

