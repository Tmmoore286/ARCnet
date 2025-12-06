# ARCnet Research Proposal

**Status**: Draft (Unclassified)

---

## Executive Summary

ARCnet delivers a commander-in-control, AI-enabled decision environment that unifies unit readiness, training requirements (TEEP), operational commitments, and funding posture into a single, explainable workflow. Key components:

- **Single Source of Truth (SSOT)** for unclassified readiness, maintenance, training/TEEP, and budget data
- **Doctrinally seeded, MOS-scoped AI agents** that reason transparently with human-in-the-loop approvals
- **ML models** for maintenance and readiness forecasting to surface bottlenecks before capability degradation
- **COA generator/evaluator** that proposes options, quantifies impacts, and preserves commander authority

**Research objectives**:
1. Working prototype focused on "Readiness Optimization Under TEEP Constraints"
2. ML maintenance/readiness forecasting integrated into the reasoning loop
3. Publishable paper documenting methods, results, and applicability

---

## Problem Statement

Commands continuously balance readiness requirements, training obligations (TEEP), operational plans, and finite resources. Current tools provide fragmented snapshots. Staff must manually merge data across domains, creating:

- **Latent risks**: Readiness dips go undetected until they degrade capability
- **Decision latency**: Cross-functional issues (maintenance + training + funding) span G-3/G-4/G-8
- **Limited auditability**: Inconsistent evidence trails reduce trust and repeatability

**Measurable targets**:
- Reduce time to assemble readiness + funds + TEEP picture from hours/days to minutes
- Predict and mitigate ≥60% of readiness dips ≥2 weeks in advance
- Provide ≥2 viable COAs per planning ask with quantified tradeoffs
- Commander usefulness ratings ≥4/5 for clarity/actionability

---

## Use Case: Readiness Optimization Under TEEP Constraints

**Primary question**: "What is my current readiness and funding posture, and how can I increase readiness without degrading my approved TEEP?"

**Scope**:
- Unit: 1st MLG (generalizable to other echelons)
- Domains: maintenance readiness, training/TEEP, personnel availability, funding posture
- Constraints: TEEP non-degradation, unclassified data only, HITL approvals at gates

**Inputs**: Readiness snapshots (G-3/G-4), maintenance logs (G-4), budget data (G-8), TEEP schedules (G-3), commander's intent

**Outputs**: Status summary, risk forecasts, 2-4 COAs with evidence citations, tasking outline

---

## Data Access Plan

**Data Owners**:
| Section | Data Types |
|---------|------------|
| G-3 | Operations/training schedules, TEEP, commander's guidance |
| G-4 | Maintenance status, logs, backlog categories, readiness indicators |
| G-8 | Historical budgets, status of funds, fiscal plans |

**Security & Compliance**:
- Unclassified only; no CUI/FOUO/PII
- Redactions applied before ingestion
- Classification metadata tracked on outputs
- Prefer local exports over live system dependencies

---

## Validation & Metrics

| Metric | Target |
|--------|--------|
| Status Accuracy | 100% match to SSOT |
| Planning Quality | Handshake score ≥0.6 |
| Status Latency | ≤5s to first checkpoint |
| Planning Latency | Org ≤20s, Mesh ≤40s |
| Usefulness | Rating ≥4/5, ≥2 viable COAs |
| Token Budget | Specialist ≤800 in / ≤300 out |

**Test Strategy**: Golden scenarios with expected outcomes, constraint compliance checks, performance profiling

---

## Risk & Ethics

**Key Risks**:
| Risk | Mitigation |
|------|------------|
| Data delays/gaps | Synthetic data with provenance marking |
| Token/cost growth | K caps, caching, multi-pass refinement |
| Bias/echo chambers | Diversity penalties, must-include coverage |
| Trust/adoption | Explainable checkpoints, evidence citations |

**DoD AI Principles Alignment**:
- **Responsible**: HITL by default, clear override controls
- **Equitable**: MOS-scoped doctrine, fairness checks
- **Traceable**: Citations, logs, JSONL audit trail
- **Reliable**: Bounded prompts, fallback modes
- **Governable**: Feature flags, kill-switch, command control

---

## Team & Stakeholders

**Sponsoring Command**: 1st MLG (G-3, G-4, G-8 as data owners/validators)

**Roles**:
- Applicant: Execution, research, prototype delivery, paper
- G-shop POCs: Data access, validation, feedback
- Mentors: Technical guidance, publication coaching

---

## Transition Plan

**Adoption Path**:
1. Pilot prototype on unclassified data
2. Create SOPs for data refresh and scenario runs
3. Train key staff with playbooks

**Exit Criteria**:
- Prototype, paper, and training materials delivered
- Measurable improvement demonstrated
- G-shop endorsement for broader pilot
