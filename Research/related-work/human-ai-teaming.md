# Human-AI Teaming: Literature Positioning

## Overview

Human-AI teaming research addresses how humans and AI systems can collaborate effectively, with particular focus on trust, autonomy allocation, and intervention mechanisms. ARCnet implements graduated autonomy with checkpoint-based human oversight.

---

## Foundational Concepts

### Levels of Automation (Sheridan & Verplanck, 1978; Parasuraman et al., 2000)

**Framework**: 10-level scale from full human control to full automation.

| Level | Description | ARCnet Equivalent |
|-------|-------------|-------------------|
| 1 | Human does everything | N/A (no AI) |
| 4 | Computer suggests alternatives | COA Generator |
| 6 | Computer acts unless human vetoes | HOTL mode |
| 8 | Computer acts, informs human | AUTO with logging |
| 10 | Full automation | AUTO without gates |

**ARCnet's position**: Configurable between levels 4-8 per stage via HITL/HOTL/AUTO modes.

### Adjustable Autonomy (Bradshaw et al., 2004)

**Key idea**: Autonomy should adapt based on context, workload, and task characteristics.

**Dimensions**:
- **Who adjusts**: Human, agent, or system
- **When**: Proactively or reactively
- **What**: Task allocation, execution method, timing

**ARCnet implementation**:
- Commander selects autonomy mode per stage
- System enforces via gate policies
- Checkpoints enable reactive adjustment (reject → modify → retry)

---

## Trust in Automation

### Lee & See (2004) - Trust in Automation

**Key factors affecting trust**:
- Performance (does it work?)
- Process (how does it work?)
- Purpose (why does it exist?)

**ARCnet's trust-building mechanisms**:

| Factor | ARCnet Feature |
|--------|----------------|
| Performance | COA quality scoring, scenario testing |
| Process | Checkpoint transparency, evidence citations |
| Purpose | Mission alignment, doctrinal grounding |

### Appropriate Trust Calibration

**Problem**: Humans tend toward over-trust (automation bias) or under-trust (automation aversion).

**ARCnet's approach**:
- Confidence scores on all outputs
- Explicit uncertainty quantification
- Evidence linking to enable verification
- Staged checkpoints for incremental trust building

---

## Intervention and Override

### Johnson et al. (2014) - Coactive Design

**Principles**:
- Observability: Agents make their activities observable
- Predictability: Humans can anticipate agent behavior
- Directability: Humans can redirect agent activities

**ARCnet implementation**:

| Principle | Implementation |
|-----------|----------------|
| Observability | Checkpoint ledger, real-time status |
| Predictability | Deterministic routing, documented agent behaviors |
| Directability | Gate approval/rejection, mode switching |

### Human-on-the-Loop (HOTL)

**Definition**: Human monitors but doesn't approve each action; can intervene when needed.

**ARCnet's HOTL mode**:
- Checkpoints auto-advance after configurable delay
- Human can pause pipeline at any checkpoint
- Intervention triggers reprocessing from that stage

---

## Military Decision-Making Context

### OODA Loop (Boyd, 1987)

**Phases**: Observe → Orient → Decide → Act

**ARCnet mapping**:

| OODA | ARCnet Stage | AI Role |
|------|--------------|---------|
| Observe | Data ingestion, SSOT | Automated |
| Orient | Scribe, Specialists | AI-assisted |
| Decide | COA Tournament, Gates | Human-AI collaborative |
| Act | Tasking | AI-generated, human-approved |

### Military Decision-Making Process (MDMP)

**ARCnet gate alignment**:

| MDMP Phase | ARCnet Gate | Checkpoint |
|------------|-------------|------------|
| Receipt of Mission | Gate A | Problem framing |
| Mission Analysis | Gate A | Mission context |
| COA Development | Gate B | Integration |
| COA Comparison | Gate C | COA ranking |
| COA Approval | Gate C | Selected COA |
| Orders Production | Gate D | Tasking |

---

## ARCnet's Contribution to HAT Literature

### Graduated Autonomy per Stage

Unlike binary autonomous/supervised modes, ARCnet allows:
- Different autonomy levels for different pipeline stages
- Per-stage configuration based on task criticality
- Dynamic adjustment during execution

### Evidence-Linked Checkpoints

Traditional XAI focuses on explaining single decisions. ARCnet extends this to:
- Multi-step reasoning chains
- Cross-agent evidence aggregation
- Checkpoint-to-checkpoint provenance

### Policy-Integrated Governance

Human oversight isn't a separate layer—it's integrated into the optimization:
- Coverage requirements ensure human perspectives are represented
- Chain-of-command factors align AI recommendations with organizational authority
- Audit trails support after-action review

---

## Open Questions

1. **Optimal autonomy allocation**: How should autonomy be distributed across stages?
2. **Trust recovery**: How do systems recover from trust violations?
3. **Cognitive load**: How many checkpoints can humans meaningfully review?
4. **Expertise calibration**: Should autonomy adapt to operator experience?

---

## References

- Sheridan, T. B., & Verplanck, W. L. (1978). Human and computer control of undersea teleoperators. MIT Man-Machine Systems Laboratory.
- Parasuraman, R., Sheridan, T. B., & Wickens, C. D. (2000). A model for types and levels of human interaction with automation. *IEEE Trans. SMC*.
- Bradshaw, J. M., et al. (2004). Dimensions of adjustable autonomy and mixed-initiative interaction. *Agents and Computational Autonomy*.
- Lee, J. D., & See, K. A. (2004). Trust in automation: Designing for appropriate reliance. *Human Factors*.
- Johnson, M., et al. (2014). Coactive design: Designing support for interdependence in joint activity. *JHFE*.
- Boyd, J. R. (1987). A discourse on winning and losing. Air University Library.
