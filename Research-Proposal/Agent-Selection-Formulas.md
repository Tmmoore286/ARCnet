# ARCnet Agent Selection — Mesh and Hybrid Modes (Formulas)

This roll-up provides presentation-ready formulas (LaTeX) for how ARCnet selects which agents to activate in Mesh and Hybrid modes. You can paste these directly into Word/PowerPoint (Insert → Equation) or a LaTeX paper.

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
