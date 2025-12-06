# ARCnet Agent Selection — Mesh and Hybrid Modes

This document provides the complete mathematical specification for ARCnet's semantic Mixture-of-Experts agent routing, including intuition, worked examples, and presentation-ready LaTeX formulas.

---

## Intuition: Why Semantic MoE Routing?

Traditional multi-agent systems face a routing dilemma:

| Approach | Problem |
|----------|---------|
| **Broadcast to all agents** | Expensive (N × LLM calls), noisy outputs, token waste |
| **Fixed routing rules** | Brittle, requires manual maintenance, poor generalization |
| **LLM-based routing** | Expensive meta-call, non-deterministic, no guarantees |

ARCnet's solution: **embed both the mission and each agent's expertise into the same vector space**, then activate only the agents whose expertise is semantically close to the mission—while ensuring mandatory coverage and penalizing redundant picks.

### Key Insight

If we embed an agent's doctrine (their T&R tasks, METL items, staff guidance) into a vector $\mathbf{v}_i$, and embed the mission query into $\mathbf{v}_m$, then:

- **High cosine similarity** $\cos(\mathbf{v}_m, \mathbf{v}_i) \approx 1$ → agent's expertise is highly relevant
- **Low cosine similarity** $\cos(\mathbf{v}_m, \mathbf{v}_i) \approx 0$ → agent's expertise is orthogonal to the mission

This geometric view lets us activate a "region" of relevant agents without expensive LLM reasoning about who should participate.

---

## Worked Example

### Setup

Consider a simplified scenario with 5 agents:

| Agent | Role | Doctrine Centroid Topics |
|-------|------|--------------------------|
| A1 | G-3 Operations | Training schedules, TEEP, readiness |
| A2 | G-4 Logistics | Maintenance, supply chain, equipment |
| A3 | G-8 Finance | Budgets, funding, fiscal year |
| A4 | Motor-T | Vehicle maintenance, transportation |
| A5 | Comm | Communications, networks, IT |

**Mission**: "What is the maintenance backlog impact on Q3 training readiness?"

### Step 1: Embed and Compute Similarity

After embedding, suppose we get these cosine similarities:

| Agent | $\cos(\mathbf{v}_m, \mathbf{v}_i)$ |
|-------|-----------------------------------|
| A1 (G-3) | 0.72 |
| A2 (G-4) | 0.85 |
| A3 (G-8) | 0.31 |
| A4 (Motor-T) | 0.78 |
| A5 (Comm) | 0.12 |

### Step 2: Filter by Threshold

With $\tau_{sim} = 0.5$, the **candidate pool** becomes:

$$\mathcal{C} = \{A1, A2, A4\}$$

A3 (Finance) and A5 (Comm) are filtered out—they're not semantically relevant to this maintenance/readiness question.

### Step 3: Compute Composite Scores

Using weights $w_{sim}=0.5$, $w_{chain}=0.2$, $w_{policy}=0.15$, $w_{ready}=0.1$, $w_{load}=0.05$:

| Agent | Similarity | Chain | Coverage | Avail | Load | **S(i)** |
|-------|------------|-------|----------|-------|------|----------|
| A1 | 0.72 | 0.9 | 1.0 | 0.8 | 0.2 | **0.36 + 0.18 + 0.15 + 0.08 - 0.01 = 0.76** |
| A2 | 0.85 | 0.8 | 1.0 | 0.9 | 0.3 | **0.425 + 0.16 + 0.15 + 0.09 - 0.015 = 0.81** |
| A4 | 0.78 | 0.5 | 0.5 | 0.7 | 0.1 | **0.39 + 0.10 + 0.075 + 0.07 - 0.005 = 0.63** |

### Step 4: Apply Diversity Penalty (Mesh Mode)

Suppose A2 and A4 are highly similar (both maintenance-focused): $\cos(\mathbf{v}_{A2}, \mathbf{v}_{A4}) = 0.82$

With $\lambda = 0.3$ and $K_{total} = 2$:

- **Option 1**: Select {A1, A2} → Total score = 0.76 + 0.81 - 0.3×0.45 = 1.435
- **Option 2**: Select {A1, A4} → Total score = 0.76 + 0.63 - 0.3×0.38 = 1.276
- **Option 3**: Select {A2, A4} → Total score = 0.81 + 0.63 - 0.3×0.82 = 1.194

**Result**: Mesh selects **{A1, A2}**—G-3 Operations and G-4 Logistics—avoiding the redundant Motor-T specialist.

### Interpretation

The diversity penalty prevented selecting two maintenance-adjacent agents (G-4 and Motor-T) when one (G-4) already covers the domain. This yields a more diverse team: operations perspective + logistics perspective.

---

## Formulas (Presentation-Ready)

## Clipboard-Ready (Word/PowerPoint/Pages)
Paste each line into an Equation box (Alt+= in Office → choose LaTeX input):

1) Slide-simple

```
A_{active} = MustInclude \cup TopK_{constrained}\!\big(S(i)\big)
```

2) Composite score

```
S(i) = w_{sim}\,\cos(v_m, v_i) + w_{chain}\,Chain(i) + w_{policy}\,Coverage(i) + w_{ready}\,Avail(i) - w_{load}\,Load(i)
```

3) Candidate pool

```
\mathcal C = \{\ i \in Agents\ :\ \cos(v_m, v_i) \ge \tau_{sim} \ \land\ Avail(i) \ge \tau_{avail}\ \}
```

4) Mesh selection

```
A_{mesh} = MustInclude \cup \underset{A \subseteq \mathcal C \setminus MustInclude}{\operatorname{argmax}}\!\left[ \sum_{i\in A} S(i) - \lambda \!\! \sum_{\substack{i<j\\ i,j\in A}} \cos(v_i, v_j) \right]
```

subject to

```
|A| \le K_{total} - |MustInclude|,\quad |A_g| \le K_g - |MustInclude_g|,\ \text{coverage satisfied}
```

5) Hybrid selection

```
K' = K_{total} - |A_{org}|,\quad \mathcal C' = \mathcal C \setminus A_{org}
```

```
A_{hybrid} = A_{org} \cup \underset{A \subseteq \mathcal C'}{\operatorname{argmax}}\!\left[ \sum_{i\in A} S(i) - \lambda \!\! \sum_{\substack{i<j\\ i,j\in A}} \cos(v_i, v_j) \right]
```

subject to

```
|A| \le K',\quad |A_g| \le K_g - |(A_{org})_g|,\ \text{coverage satisfied}
```

## Notation
- \(\mathbf v_m\): mission/request embedding
- \(\mathbf v_i\): agent/billet doctrine centroid embedding
- \(\cos(\cdot,\cdot)\): cosine similarity in embedding space
- \(\mathrm{Chain}(i),\ \mathrm{Coverage}(i),\ \mathrm{Avail}(i),\ \mathrm{Load}(i) \in [0,1]\): chain-of-command fit, policy/must-include coverage, readiness/availability, and current load
- MustInclude: mandated shops/agents set
- Shop caps: \(K_{\text{total}}\) overall, \(K_g\) per shop \(g\)
- Thresholds: \(\tau_{\mathrm{sim}}\) (similarity), \(\tau_{\mathrm{avail}}\) (availability)
- Diversity weight: \(\lambda \ge 0\)

## Composite Score
$$
S(i) \,=\, w_{\mathrm{sim}}\,\cos(\mathbf v_m, \mathbf v_i)
\; +\; w_{\mathrm{chain}}\,\mathrm{Chain}(i)
\; +\; w_{\mathrm{policy}}\,\mathrm{Coverage}(i)
\; +\; w_{\mathrm{ready}}\,\mathrm{Avail}(i)
\; -\; w_{\mathrm{load}}\,\mathrm{Load}(i)
$$

## Candidate Pool
$$
\mathcal C \,=\, \{\ i \in \mathcal A\ :\ \cos(\mathbf v_m, \mathbf v_i) \ge \tau_{\mathrm{sim}},\ \ \mathrm{Avail}(i) \ge \tau_{\mathrm{avail}}\ \}
$$

## Mesh Mode Selection
Let \(M=\mathrm{MustInclude}\). Select additional agents by maximizing score with a redundancy penalty, under caps/coverage:
$$
A_{\mathrm{mesh}} \,=\, M\ \cup\ \underset{A \subseteq \mathcal C \setminus M}{\arg\max}\left[\ \sum_{i \in A} S(i)\ -\ \lambda \!\! \sum_{\substack{i<j\\ i,j \in A}}\!\! \cos(\mathbf v_i, \mathbf v_j)\ \right]
$$
subject to
$$
|A| \le K_{\text{total}} - |M|,\quad |A_g| \le K_g - |M_g|\ \ \forall g,\quad \text{required-shop coverage satisfied.}
$$

## Hybrid Mode Selection
Let \(A_{\mathrm{org}}\) be the deterministic org‑lane set (status retrieval). Use remaining capacity and exclude already selected agents:
$$
K' \,=\, K_{\text{total}} - |A_{\mathrm{org}}|,\qquad \mathcal C' \,=\, \mathcal C \setminus A_{\mathrm{org}}
$$
$$
A_{\mathrm{hybrid}} \,=\, A_{\mathrm{org}}\ \cup\ \underset{A \subseteq \mathcal C'}{\arg\max}\left[\ \sum_{i \in A} S(i)\ -\ \lambda \!\! \sum_{\substack{i<j\\ i,j \in A}}\!\! \cos(\mathbf v_i, \mathbf v_j)\ \right]
$$
subject to
$$
|A| \le K',\quad |A_g| \le K_g - |(A_{\mathrm{org}})_g|\ \ \forall g,\quad \text{required-shop coverage satisfied.}
$$

## Slide-Simple Form
For compact slides, use the shorthand and footnote the constraints:
$$
A_{\mathrm{active}} \,=\, \mathrm{MustInclude} \cup \mathrm{TopK}_{\text{constrained}}\big(S(i)\big)
$$

## Notes
- Diversity penalty discourages redundant picks among highly similar agents; set \(\lambda=0\) to disable.
- Required-shop coverage can be encoded either via MustInclude or as a hard constraint in the optimizer.
- Thresholds \(\tau_{\mathrm{sim}}, \tau_{\mathrm{avail}}\) screen out low-relevance or unavailable agents before selection.

## Word/PowerPoint Usage
- Word/PowerPoint: Insert → Equation → paste the LaTeX between \(\$\$\) delimiters (delimiters optional in Word). Example: `S(i) = w_{sim}\,cos(v_m,v_i) + ...`.
- LaTeX/Overleaf: copy any block above directly into your paper; requires `amsmath`.

---

## Parameter Tuning Guide

### Similarity Threshold ($\tau_{sim}$)

| Value | Effect | Use When |
|-------|--------|----------|
| 0.3 (low) | Broad candidate pool, more agents considered | Exploratory queries, unfamiliar domains |
| 0.5 (medium) | Balanced filtering | General-purpose default |
| 0.7 (high) | Strict relevance requirement | Well-defined, narrow queries |

### Diversity Penalty ($\lambda$)

| Value | Effect | Use When |
|-------|--------|----------|
| 0.0 | No diversity pressure, pure score maximization | Coverage is paramount |
| 0.1-0.3 | Mild redundancy discouragement | Default for most scenarios |
| 0.5+ | Strong diversity enforcement | Large agent pools, risk of echo chambers |

### Weight Tuning ($w_{sim}, w_{chain}, w_{policy}, w_{ready}, w_{load}$)

Recommended starting points:

| Context | $w_{sim}$ | $w_{chain}$ | $w_{policy}$ | $w_{ready}$ | $w_{load}$ |
|---------|-----------|-------------|--------------|-------------|------------|
| **Research/exploration** | 0.6 | 0.1 | 0.1 | 0.15 | 0.05 |
| **Operational planning** | 0.4 | 0.25 | 0.2 | 0.1 | 0.05 |
| **Crisis response** | 0.3 | 0.3 | 0.15 | 0.2 | 0.05 |

---

## Edge Cases

### Edge Case 1: Empty Candidate Pool

**Scenario**: No agents pass the similarity threshold.

**Solution**: Fall back to MustInclude set only, or lower $\tau_{sim}$ dynamically:
```
if |C| == 0:
    τ_sim = τ_sim * 0.8  # Relax threshold
    recompute C
```

### Edge Case 2: All Agents Highly Similar

**Scenario**: Specialized organization where all agents have similar doctrine.

**Solution**: Increase $\lambda$ or rely more heavily on governance factors ($w_{chain}$, $w_{policy}$).

### Edge Case 3: MustInclude Exceeds Capacity

**Scenario**: $|M| > K_{total}$

**Solution**: This is a configuration error. Either increase $K_{total}$ or prioritize within MustInclude.

### Edge Case 4: Conflicting Coverage Requirements

**Scenario**: Required shops have no available agents.

**Solution**: System emits warning and proceeds with partial coverage, flagging the gap for human review.

---

## Computational Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Embedding similarity | $O(N \cdot d)$ | N agents, d embedding dimensions |
| Candidate filtering | $O(N)$ | Single pass |
| Score computation | $O(N)$ | Single pass over candidates |
| Diversity penalty (brute force) | $O(N^2)$ | Pairwise similarity in selected set |
| Optimal selection (exact) | $O(2^N)$ | NP-hard subset selection |
| Greedy approximation | $O(N \cdot K)$ | K agents to select |

**Practical approach**: Use greedy selection with diversity-aware insertion for real-time performance. Exact optimization only needed for small N or offline analysis.

---

## References

- Shazeer, N., et al. (2017). Outrageously Large Neural Networks: The Sparsely-Gated Mixture-of-Experts Layer.
- Fedus, W., et al. (2022). Switch Transformers: Scaling to Trillion Parameter Models with Simple and Efficient Sparsity.
- Carbonell, J., & Goldstein, J. (1998). The Use of MMR, Diversity-Based Reranking for Reordering Documents and Producing Summaries. (Maximal Marginal Relevance—inspiration for diversity penalty)
