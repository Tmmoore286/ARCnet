# Literature Review and Positioning

This document positions ARCnet within four research domains: Mixture of Experts, Multi-Agent Systems, Human-AI Teaming, and Explainable AI.

---

## 1. Mixture of Experts (MoE)

### Foundations

MoE architectures route inputs to specialized sub-networks via gating mechanisms. Key works:

- **Jacobs et al. (1991)**: Established expert specialization + gating architecture
- **Shazeer et al. (2017)**: Sparse activation via learned gating: $G(x) = \text{Softmax}(\text{TopK}(x \cdot W_g))$
- **Fedus et al. (2022)**: Switch Transformers with load balancing

### Recent Models

| Model | Architecture | Routing |
|-------|--------------|---------|
| Mixtral | 8 experts, top-2 activation | Learned linear gating |
| DeepSeek-MoE | Fine-grained + shared experts | Learned with balancing |

### ARCnet's Differentiation

| Aspect | Neural MoE | ARCnet |
|--------|-----------|--------|
| Gating | Learned weights | Semantic similarity + policy |
| Interpretability | Low | High (explicit scores) |
| Diversity | Implicit | Explicit λ penalty |
| Constraints | Training loss | First-class optimization terms |

**Key contribution**: ARCnet replaces learned gating with interpretable semantic routing while adding policy constraints that cannot be learned end-to-end.

---

## 2. Multi-Agent Systems (MAS)

### Foundations

- **Wooldridge (2009)**: Agent properties (autonomy, reactivity, proactivity, social ability)
- **Contract Net (Smith, 1980)**: Task announcement → bidding → awarding

### LLM Agent Frameworks

| Framework | Routing | Cost | Determinism |
|-----------|---------|------|-------------|
| AutoGen | LLM-based or hardcoded | High | Low |
| CrewAI | Process types | Medium | Medium |
| LangGraph | Conditional edges | Medium | Medium |
| **ARCnet** | Semantic similarity | Low | High |

### ARCnet's Differentiation

1. **Semantic coordination**: Embedding similarity replaces capability ontologies and bidding
2. **Diversity-aware selection**: Explicit penalty prevents groupthink
3. **Hybrid modes**: Systematic comparison of Org/Mesh/Hybrid routing

---

## 3. Human-AI Teaming (HAT)

### Foundations

- **Sheridan & Verplanck (1978)**: 10-level automation scale
- **Parasuraman et al. (2000)**: Types and levels of automation
- **Bradshaw et al. (2004)**: Adjustable autonomy dimensions

### Trust and Intervention

- **Lee & See (2004)**: Trust factors (performance, process, purpose)
- **Johnson et al. (2014)**: Coactive design (observability, predictability, directability)

### ARCnet's Implementation

| Automation Level | Description | ARCnet Mode |
|------------------|-------------|-------------|
| 4 | Suggests alternatives | COA Generator |
| 6 | Acts unless vetoed | HOTL |
| 8 | Acts, informs human | AUTO with logging |

**Key contribution**: Per-stage autonomy configuration aligned to MDMP phases, with checkpoint-based intervention.

---

## 4. Explainable AI (XAI)

### Foundations

- **DARPA XAI (Gunning et al., 2019)**: Goals for explainable models
- **Arrieta et al. (2020)**: Taxonomy (local, global, example-based, feature attribution)

### Explanation Methods

| Method | Approach | ARCnet Alternative |
|--------|----------|-------------------|
| Attention | Infer importance from weights | Explicit scoring function |
| LIME/SHAP | Post-hoc approximation | Built-in interpretability |
| Chain-of-thought | Verbalized reasoning | Checkpoint structure |

### ARCnet's Differentiation

1. **Structural explainability**: Scoring terms ARE the explanation
2. **Multi-agent synthesis**: Integrator surfaces how perspectives combined
3. **Evidence provenance**: Quote-level citations, not just document references

---

## Summary: ARCnet's Position

```
                    Neural MoE
                   (Learned Gating)
                        │
                        │ Semantic routing
                        │ + policy constraints
                        ▼
    Multi-Agent ◄───── ARCnet ─────► Human-AI Teaming
    Systems            │              (Per-stage autonomy)
    (Embedding-based   │
     coordination)     │ Checkpoint-based
                       │ evidence linking
                       ▼
                 Explainable AI
                 (Structural transparency)
```

| Innovation | Prior Approach | ARCnet Approach |
|------------|----------------|-----------------|
| Expert routing | Learned/hardcoded | Semantic + policy |
| Diversity | Implicit/none | Explicit penalty |
| Governance | Post-hoc | Optimization term |
| Autonomy | Binary | Per-stage graduated |
| Explanation | Post-hoc | Built-in structure |

---

## References

### Mixture of Experts
- Jacobs, R. A., et al. (1991). Adaptive mixtures of local experts. *Neural Computation*.
- Shazeer, N., et al. (2017). Outrageously large neural networks: The sparsely-gated MoE layer. *ICLR*.
- Fedus, W., et al. (2022). Switch transformers. *JMLR*.
- Carbonell, J., & Goldstein, J. (1998). MMR diversity-based reranking. *SIGIR*.

### Multi-Agent Systems
- Wooldridge, M. (2009). An Introduction to MultiAgent Systems. Wiley.
- Smith, R. G. (1980). The contract net protocol. *IEEE Trans. Computers*.
- Wu, Q., et al. (2023). AutoGen. *arXiv preprint*.

### Human-AI Teaming
- Parasuraman, R., et al. (2000). Types and levels of human interaction with automation. *IEEE Trans. SMC*.
- Lee, J. D., & See, K. A. (2004). Trust in automation. *Human Factors*.
- Johnson, M., et al. (2014). Coactive design. *JHFE*.

### Explainable AI
- Gunning, D., et al. (2019). XAI—Explainable artificial intelligence. *Science Robotics*.
- Arrieta, A. B., et al. (2020). Explainable AI: Concepts and challenges. *Information Fusion*.
- Miller, T. (2019). Explanation in AI: Insights from social sciences. *Artificial Intelligence*.
