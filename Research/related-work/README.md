# Related Work

This folder positions ARCnet within the broader research landscape across four key domains.

## Contents

| Document | Domain | Key Question |
|----------|--------|--------------|
| [mixture-of-experts.md](mixture-of-experts.md) | Neural Architecture | How does ARCnet's semantic routing relate to neural MoE gating? |
| [multi-agent-systems.md](multi-agent-systems.md) | Distributed AI | How does ARCnet extend MAS coordination patterns? |
| [human-ai-teaming.md](human-ai-teaming.md) | Human Factors | How does ARCnet implement adjustable autonomy? |
| [explainable-ai.md](explainable-ai.md) | XAI | How does ARCnet achieve transparency in multi-agent workflows? |

## Summary Positioning

ARCnet occupies a unique intersection:

```
                    Neural MoE
                   (Learned Gating)
                        │
                        │ ARCnet uses semantic
                        │ similarity instead of
                        │ learned gating
                        ▼
    Multi-Agent ◄───── ARCnet ─────► Human-AI Teaming
    Systems            │              (Adjustable Autonomy)
    (Coordination)     │
                       │ Evidence-linked
                       │ checkpoints
                       ▼
                 Explainable AI
                 (Transparency)
```

## Key Differentiators

| Aspect | Prior Work | ARCnet Innovation |
|--------|------------|-------------------|
| Expert routing | Learned gating (neural) or hardcoded rules | Semantic similarity + policy constraints |
| Diversity | Implicit (training loss) or none | Explicit penalty term (λ) |
| Governance | Post-hoc filtering | First-class optimization term |
| Auditability | Attention weights or logs | Checkpoint ledger with evidence citations |
| Autonomy | Binary (on/off) | Graduated (HITL → HOTL → AUTO) per stage |
