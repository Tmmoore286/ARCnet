# ARCnet: Research Overview

## Abstract

This research introduces a **semantic Mixture-of-Experts (MoE) architecture for multi-agent orchestration** in organizational decision support systems. Unlike neural MoE approaches where gating networks learn expert routing, ARCnet employs embedding-based similarity matching between mission queries and agent doctrine centroids, combined with policy constraints and diversity penalties, to achieve sparse, relevant, and interpretable expert activation.

The system addresses a fundamental limitation in current multi-agent AI frameworks: the tension between computational efficiency (activating few experts) and decision quality (ensuring comprehensive coverage). ARCnet resolves this through a mathematically principled selection mechanism that:

1. Routes missions to semantically relevant agents via cosine similarity in embedding space
2. Enforces organizational constraints (chain-of-command, mandatory coverage) as first-class optimization terms
3. Penalizes redundant expertise to yield compact, diverse teams
4. Maintains full auditability through checkpoint-based reasoning with evidence citations
5. Leverages multi-provider LLM coordination with task-based routing and dual-judge consensus scoring

Preliminary analysis suggests 40-60% reduction in LLM calls compared to fixed full-staff activation while improving contextual relevance of agent outputs.

---

## Research Questions

### Primary Research Question

**RQ1**: Can semantic embedding-based expert routing with diversity penalties achieve comparable or superior decision quality to fixed-roster or LLM-routed multi-agent systems while significantly reducing computational cost?

### Secondary Research Questions

**RQ2**: How do the three computational pathways (Organizational, Mesh, Hybrid) compare in terms of:
- Decision quality (measured via rubric-scored COA evaluation)
- Computational efficiency (token consumption, latency)
- Coverage completeness (did relevant perspectives get included?)

**RQ3**: What is the optimal diversity penalty (λ) for balancing team compactness against coverage?

**RQ4**: How does MOS-scoped doctrine seeding via embedding similarity compare to prompt-based expert knowledge injection?

**RQ5**: What autonomy configurations (HITL/HOTL/AUTO) yield optimal human-AI team performance across different decision complexity levels?

**RQ6**: Does dual-judge COA evaluation (using two LLM providers) produce more robust scoring than single-judge evaluation, and what disagreement thresholds effectively identify cases requiring human review?

---

## Hypotheses

**H1**: Mesh mode routing will achieve equivalent COA quality scores to Organizational mode with 40-60% fewer activated agents on cross-functional planning tasks.

**H2**: Hybrid mode will outperform both pure Org and pure Mesh modes on tasks requiring both status retrieval and creative planning.

**H3**: Increasing diversity penalty (λ) will improve decision quality up to a threshold, beyond which coverage gaps degrade performance.

**H4**: Semantic doctrine seeding will produce more contextually relevant specialist outputs than generic role-based prompting.

**H5**: Dual-judge COA evaluation will achieve higher inter-rater reliability with human expert scores than single-judge evaluation, particularly for edge cases where model biases diverge.

---

## Methodology

### Experimental Design

1. **Golden Scenario Corpus**: Curated set of decision scenarios with known-good COA outcomes, spanning:
   - Routine status queries (Org-favored)
   - Cross-functional planning (Mesh-favored)
   - Mixed requirements (Hybrid-favored)

2. **Ablation Studies**:
   - Vary routing mode (Org/Mesh/Hybrid) with fixed scenarios
   - Vary diversity penalty (λ = 0, 0.1, 0.2, 0.5, 1.0)
   - Vary similarity threshold (τ_sim = 0.3, 0.5, 0.7)

3. **Metrics**:
   - COA quality score (expert-rubric evaluation)
   - Token consumption (total LLM tokens across pipeline)
   - Agent activation count
   - Coverage score (percentage of relevant domains addressed)
   - Decision latency (end-to-end time)

### Evaluation Framework

See [Validation-and-Metrics.md](Validation-and-Metrics.md) and [Appendices/Appendix-C-Metrics-and-Rubrics.md](Appendices/Appendix-C-Metrics-and-Rubrics.md) for detailed rubrics.

---

## Contributions

This research makes the following contributions:

1. **Architectural**: A novel semantic MoE framework for multi-agent systems that bridges neural gating mechanisms with human-interpretable organizational structures.

2. **Algorithmic**: Formal specification of diversity-penalized agent selection with policy constraints (see [Agent-Selection-Formulas.md](Agent-Selection-Formulas.md)).

3. **Empirical**: Comparative evaluation of routing strategies (Org/Mesh/Hybrid) across decision complexity levels.

4. **Applied**: Demonstration of human-AI teaming in military decision-making processes with configurable autonomy and full auditability.

---

## Relation to Literature

### Multi-Agent Systems
ARCnet extends work on multi-agent coordination (Wooldridge, 2009; Dorri et al., 2018) by introducing semantic routing based on organizational doctrine rather than hardcoded interaction protocols.

### Mixture of Experts
While neural MoE architectures (Shazeer et al., 2017; Fedus et al., 2022) learn gating functions end-to-end, ARCnet uses pre-computed embeddings and explicit optimization, enabling interpretability and policy integration.

### Human-AI Teaming
The graduated autonomy model (HITL → HOTL → AUTO) builds on adjustable autonomy research (Bradshaw et al., 2004; Johnson et al., 2014) with checkpoint-based intervention points aligned to established decision processes.

### Explainable AI
Evidence-linked reasoning with citation-level provenance extends XAI approaches (Gunning et al., 2019) to multi-agent workflows where transparency spans multiple reasoning steps.

See [LITERATURE.md](LITERATURE.md) for detailed literature positioning.

---

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| Core Architecture | ✅ Complete | Domain models, agent protocols, orchestration |
| Agent Selection | ✅ Complete | Embedding-based routing, diversity penalty |
| COA Tournament | ✅ Complete | Generation, evaluation, ranking |
| Gate Enforcement | ✅ Complete | HITL/HOTL/AUTO with checkpoints |
| Multi-LLM Coordination | ✅ Complete | Task-based routing, dual-judge COA evaluation |
| ML Forecasting | 🔄 In Progress | Predictive maintenance, budget models |
| Empirical Evaluation | 📋 Planned | Golden scenario corpus, ablation studies |
| Paper Draft | 📋 Planned | Target: conference submission |

---

## Documentation Map

| Document | Purpose |
|----------|---------|
| [PROPOSAL.md](PROPOSAL.md) | Program proposal (problem, use case, metrics, risks) |
| [Technical-Approach.md](Technical-Approach.md) | System design and methodology |
| [Agent-Selection-Formulas.md](Agent-Selection-Formulas.md) | Mathematical specification with examples |
| [LITERATURE.md](LITERATURE.md) | Literature review and positioning |
| [Appendices/](Appendices/) | Detailed rubrics, ML specs, scenarios |

---

## Contact

**Timothy Moore**
GitHub: [@Tmmoore286](https://github.com/Tmmoore286)
