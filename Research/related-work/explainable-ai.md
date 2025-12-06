# Explainable AI: Literature Positioning

## Overview

Explainable AI (XAI) research addresses how AI systems can provide understandable justifications for their outputs. ARCnet extends XAI to multi-agent workflows with checkpoint-based evidence linking.

---

## XAI Foundations

### DARPA XAI Program (Gunning et al., 2019)

**Goals**:
- Produce more explainable models
- Enable users to understand AI behavior
- Maintain high performance

**ARCnet's alignment**: Prioritizes explainability without sacrificing decision quality through evidence-linked reasoning.

### Taxonomy of Explanations (Arrieta et al., 2020)

| Type | Description | ARCnet Example |
|------|-------------|----------------|
| **Local** | Explains single prediction | Why agent A was selected for this mission |
| **Global** | Explains model behavior | How similarity thresholds affect routing |
| **Example-based** | References similar cases | Previous missions with similar agent configurations |
| **Feature attribution** | Which inputs mattered | Similarity scores, policy factors in composite score |

---

## Explanation Methods

### Attention-Based Explanations

**Approach**: Use attention weights to indicate input importance.

**Limitations**: Attention doesn't always correlate with causal importance (Jain & Wallace, 2019).

**ARCnet's approach**: Explicit scoring function makes importance weights directly observable—not inferred from attention.

### Post-Hoc Explanations (LIME, SHAP)

**Approach**: Approximate model behavior with interpretable local models.

**Limitations**: Approximation fidelity varies; can be computationally expensive.

**ARCnet's approach**: No post-hoc approximation needed—the scoring function IS the explanation:

$$S(i) = w_{sim} \cos(\mathbf{v}_m, \mathbf{v}_i) + w_{chain} \text{Chain}(i) + \ldots$$

Each term directly shows why an agent scored as it did.

### Chain-of-Thought (Wei et al., 2022)

**Approach**: Prompt LLMs to verbalize reasoning steps.

**ARCnet's extension**: Chain-of-thought within agents + checkpoint structure across agents:

```
Mission → Scribe reasoning → Coordinator reasoning →
    Specialist A reasoning ─┐
    Specialist B reasoning ─┼─→ Integrator reasoning → COA
    Specialist C reasoning ─┘
```

---

## Multi-Agent Explainability

### Challenge: Distributed Reasoning

When multiple agents contribute to a decision:
- Which agent's reasoning was decisive?
- How did agent outputs interact?
- Where did disagreements occur?

### ARCnet's Checkpoint Architecture

Each checkpoint captures:

```json
{
  "stage": "specialist_logistics",
  "agent_id": "G4_001",
  "input_context": { "mission": "...", "ssot_queries": [...] },
  "reasoning": "The maintenance backlog shows...",
  "evidence": [
    { "source": "maint_log_q3", "section": "2.1", "quote": "..." }
  ],
  "output": { "assessment": "...", "confidence": 0.82 },
  "timestamp": "2025-12-06T14:30:00Z"
}
```

This enables:
- **Traceability**: Follow reasoning from mission to COA
- **Attribution**: Identify which specialist raised which concern
- **Verification**: Check evidence citations against source documents

---

## Evidence Linking

### Citation-Level Provenance

Traditional RAG systems cite documents. ARCnet cites specific sections:

| Level | Example | Value |
|-------|---------|-------|
| Document | "See maintenance report" | Low—requires manual search |
| Section | "See maintenance report §2.1" | Medium—narrowed scope |
| Quote | "See §2.1: 'Backlog increased 40%'" | High—directly verifiable |

ARCnet targets quote-level citations where possible.

### Evidence Aggregation

When multiple specialists cite the same source:
- Track citation frequency (heavily-cited = important)
- Detect contradictory interpretations
- Surface for human review at integration stage

---

## Explanation for Different Audiences

### Miller (2019) - Explanation in AI

**Key insight**: Good explanations are contrastive ("Why X rather than Y?") and selective (focused, not exhaustive).

**ARCnet's multi-audience explanations**:

| Audience | Explanation Type | ARCnet Feature |
|----------|------------------|----------------|
| Commander | High-level summary | COA comparison matrix |
| Staff officer | Detailed reasoning | Specialist checkpoints |
| Analyst | Evidence trail | Citation provenance |
| Auditor | Complete record | Checkpoint ledger (JSONL) |

---

## ARCnet's Contribution to XAI Literature

### Structural Explainability

Instead of explaining a black-box model post-hoc, ARCnet builds explanation into the structure:
- Scoring function terms are interpretable
- Checkpoint stages map to decision phases
- Evidence citations are first-class outputs

### Multi-Agent Explanation Synthesis

The Integrator stage explicitly:
- Synthesizes specialist outputs
- Resolves contradictions
- Surfaces disagreements

This creates a "meta-explanation" of how diverse perspectives combined.

### Explanation for High-Stakes Domains

Military/organizational decisions require:
- Audit trails (legal/policy compliance)
- Accountability (who decided what)
- Reproducibility (same inputs → same outputs)

ARCnet's deterministic routing and checkpoint architecture satisfy all three.

---

## Evaluation of Explanations

### Metrics (Hoffman et al., 2018)

| Metric | Description | ARCnet Evaluation |
|--------|-------------|-------------------|
| Goodness | Quality of explanation | User studies on checkpoint clarity |
| Satisfaction | User contentment | Post-decision surveys |
| Curiosity | Desire to learn more | Drill-down rate in UI |
| Trust | Confidence in system | Autonomy level selected over time |
| Performance | Task success | COA quality + implementation success |

---

## Open Questions

1. **Explanation fidelity**: Do checkpoint explanations accurately reflect agent reasoning?
2. **Cognitive load**: How much explanation is too much?
3. **Explanation manipulation**: Can adversarial inputs generate misleading explanations?
4. **Temporal explanation**: How to explain changes in reasoning over multiple iterations?

---

## References

- Gunning, D., et al. (2019). XAI—Explainable artificial intelligence. *Science Robotics*.
- Arrieta, A. B., et al. (2020). Explainable Artificial Intelligence (XAI): Concepts, taxonomies, opportunities and challenges. *Information Fusion*.
- Jain, S., & Wallace, B. C. (2019). Attention is not explanation. *NAACL*.
- Wei, J., et al. (2022). Chain-of-thought prompting elicits reasoning in large language models. *NeurIPS*.
- Miller, T. (2019). Explanation in artificial intelligence: Insights from the social sciences. *Artificial Intelligence*.
- Hoffman, R. R., et al. (2018). Metrics for explainable AI: Challenges and prospects. *arXiv preprint*.
