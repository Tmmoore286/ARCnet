# ARCnet Proposal Diagrams

These Mermaid sources render cleanly to PNG/SVG for papers and slides.

Files
- `01-Commander-Flow.mmd` — Commander-in-control agentic workflow with HITL gates and checkpoints.
- `02-Agent-Activation.mmd` — Mesh vs Hybrid activation from mission embedding to active set with constraints.
- `03-SSOT-Architecture.mmd` — On-device architecture, CoreData SSOT, importers, LLM-only network, guardrails.
- `04-COA-Tournament.mmd` — Tournament scorecard and approval path.

Render options
- Quickest: https://mermaid.live → paste file contents → Export PNG/SVG.
- CLI (optional): `brew install mermaid-cli` then:
  - `mmdc -i 01-Commander-Flow.mmd -o 01-Commander-Flow.png`
  - `mmdc -i 02-Agent-Activation.mmd -o 02-Agent-Activation.png`
  - `mmdc -i 03-SSOT-Architecture.mmd -o 03-SSOT-Architecture.png`
  - `mmdc -i 04-COA-Tournament.mmd -o 04-COA-Tournament.png`

Tips
- Keep fonts large for readability; 1400–1800 px width works well for slides.
- Use the equations from `Agent-Selection-Formulas.md` as captions or callouts next to the activation diagram.
- If you need static vector outputs for Word, export SVG and insert.
