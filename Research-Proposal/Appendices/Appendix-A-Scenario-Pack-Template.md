# Appendix A — Scenario Pack Template (Unclassified)

Purpose
Standardize scenario‑driven testing to verify accuracy, timeliness, and usefulness.

Template (YAML or JSON)
```yaml
scenario_id: SCEN-001
name: Readiness Optimization Under TEEP Constraints
unit: 1st MLG
timeframe: FY26-Q2
assumptions:
  - unclassified_only
  - no_TEEP_degradation
inputs:
  readiness_snapshot: path/to/readiness_snapshot.json
  maintenance_logs: path/to/maintenance_logs.json
  funds: path/to/funds_status.json
  teep: path/to/teep_schedule.json
  commander_context: path/to/mission_context.json
expected:
  status_truth:
    checks: ["availability_matches", "funds_status_matches", "teep_dates_match"]
  planning:
    winner_coa_id: COA-2
    ranking: [COA-2, COA-1, COA-3]
    constraints_honored: true
    handshake_min: 0.6
    evidence_ids: [DOC-TR-001, DOC-TR-014, REF-LOG-003]
metrics:
  latency_slo:
    status_first_checkpoint_s: 5
    planning_end_to_end_s: 40
notes: |
  This scenario features high maintenance backlog and available parts funding; TEEP locked in Q2.
```

Files
- Keep files unclassified and redacted; prefer aggregates over raw line‑level data.
- Store under a controlled, unclassified path with versioned filenames.

