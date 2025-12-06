# Mixture of Experts: Literature Positioning

## Overview

Mixture of Experts (MoE) architectures route inputs to specialized sub-networks (experts) via a gating mechanism, enabling parameter-efficient scaling. ARCnet adapts this paradigm from neural network layers to multi-agent orchestration.

---

## Foundational Work

### Jacobs et al. (1991) - Adaptive Mixtures of Local Experts

**Key idea**: Divide complex tasks among specialized modules; a gating network learns to weight expert outputs.

**Relevance to ARCnet**: Established the expert specialization + gating architecture that ARCnet generalizes to organizational agents.

### Shazeer et al. (2017) - Sparsely-Gated MoE Layer

**Key idea**: Scale models to 137B parameters by activating only top-k experts per token via a learned gating function.

$$G(x) = \text{Softmax}(\text{TopK}(x \cdot W_g))$$

**Relevance to ARCnet**: Demonstrated efficiency gains from sparse activation. ARCnet achieves similar sparsity through semantic similarity thresholding rather than learned gating.

### Fedus et al. (2022) - Switch Transformers

**Key idea**: Simplify MoE routing to single-expert selection (k=1) with load balancing auxiliary loss.

**Relevance to ARCnet**: ARCnet's capacity constraints ($K_{total}$, $K_g$) serve a similar load-balancing function.

---

## Recent Developments

### Mixtral (Mistral AI, 2023)

**Architecture**: 8 experts per layer, 2 activated per token, 46.7B total / 12.9B active parameters.

**Routing**: Learned linear gating layer selects top-2 experts.

**Comparison to ARCnet**:

| Aspect | Mixtral | ARCnet |
|--------|---------|--------|
| Expert type | FFN sublayers | Organizational agents |
| Gating | Learned linear projection | Cosine similarity + policy |
| Interpretability | Low (learned weights) | High (semantic similarity scores) |
| Diversity | Implicit via training | Explicit λ penalty |

### DeepSeek-MoE (2024)

**Innovation**: Fine-grained expert segmentation with shared experts for common knowledge.

**Relevance to ARCnet**: The "MustInclude" set in ARCnet serves a similar function to shared experts—ensuring critical perspectives regardless of routing.

---

## ARCnet's Contribution to MoE Literature

### From Neural Gating to Semantic Routing

Traditional MoE:
$$G(x) = \text{Softmax}(W_g \cdot x)$$

ARCnet:
$$S(i) = w_{sim} \cos(\mathbf{v}_m, \mathbf{v}_i) + \text{policy terms}$$

**Key difference**: ARCnet's "gating" is interpretable—we can inspect why agent A was activated (high similarity to mission) rather than relying on opaque learned weights.

### Policy-Constrained Expert Selection

Neural MoE optimizes for task performance. ARCnet adds governance constraints:

- Chain-of-command fit
- Coverage requirements
- Workload balancing

These cannot be learned end-to-end but must be specified as domain constraints.

### Diversity as Explicit Objective

Neural MoE relies on training dynamics to avoid expert collapse. ARCnet uses an explicit diversity penalty:

$$-\lambda \sum_{i<j} \cos(\mathbf{v}_i, \mathbf{v}_j)$$

Inspired by Maximal Marginal Relevance (Carbonell & Goldstein, 1998), this ensures diverse perspectives are activated.

---

## Open Questions

1. **Hybrid approaches**: Could learned gating refine semantic similarity scores?
2. **Adaptation**: Can agent embeddings be fine-tuned based on mission outcomes?
3. **Hierarchical routing**: Can MoE principles apply at multiple organizational levels?

---

## References

- Jacobs, R. A., Jordan, M. I., Nowlan, S. J., & Hinton, G. E. (1991). Adaptive mixtures of local experts. *Neural Computation*.
- Shazeer, N., et al. (2017). Outrageously large neural networks: The sparsely-gated mixture-of-experts layer. *ICLR*.
- Fedus, W., Zoph, B., & Shazeer, N. (2022). Switch transformers: Scaling to trillion parameter models. *JMLR*.
- Jiang, A. Q., et al. (2024). Mixtral of experts. *arXiv preprint*.
- Dai, D., et al. (2024). DeepSeekMoE: Towards ultimate expert specialization. *arXiv preprint*.
- Carbonell, J., & Goldstein, J. (1998). The use of MMR, diversity-based reranking. *SIGIR*.
