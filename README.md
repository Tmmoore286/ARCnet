# ARCnet — Agentic Decision Support System

An iPad application exploring **human-AI collaboration in complex decision-making environments**. ARCnet implements a multi-agent architecture with configurable autonomy levels, demonstrating research concepts in explainable AI, human-in-the-loop (HITL) systems, and organizational decision support.

## Research Focus

This project investigates several key research questions:

1. **Human-AI Autonomy Spectrum**: How can systems support variable autonomy levels (HITL, Human-on-the-Loop, Autonomous) while maintaining accountability and explainability?

2. **Multi-Agent Coordination**: How do specialized AI agents collaborate through structured workflows to support complex organizational decisions?

3. **Explainable Decision Pipelines**: How can AI reasoning be made transparent through checkpoints, evidence linking, and audit trails?

4. **Organizational Digital Twins**: How can hierarchical organizations be modeled digitally to enable AI-assisted planning and analysis?

## Architecture Overview

```
Mission Input → Scribe → Coordinator → Specialists → Integrator → Evaluator → COAs → Approval → Tasking
                   ↓          ↓            ↓            ↓           ↓         ↓
              [Checkpoint] [Checkpoint] [Checkpoint] [Checkpoint] [Checkpoint] [Checkpoint]
```

- **Stage-Based Processing**: Each decision phase produces explainable checkpoints with rationale, evidence, and confidence scores
- **Configurable Autonomy**: Per-agent autonomy modes (HITL/HOTL/Autonomous) with approval gates
- **Evidence Linking**: All outputs cite source documents with section-level granularity
- **Audit Trail**: Complete logging in JSONL format for post-hoc analysis

## Technical Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6 |
| UI Framework | SwiftUI + Combine |
| Visualization | SceneKit + Swift Charts |
| Data Layer | CoreData |
| Architecture | MVVM + Coordinator |
| LLM Integration | Protocol-based abstraction (OpenAI implementation) |

## Key Documents

| Document | Description |
|----------|-------------|
| [Canonical-OVERVIEW.md](Canonical-OVERVIEW.md) | Product specification and UI design |
| [CODEX.md](CODEX.md) | Technical architecture and implementation guide |
| [AGENTS.md](AGENTS.md) | Agent development workflow and constraints |
| [Flow-Mode-Proposal.md](Flow-Mode-Proposal.md) | Research proposal for adaptive routing algorithms |

## Running the Application

### Prerequisites
- Xcode 16+ (Swift 6)
- iPadOS 18+ simulator or device
- OpenAI API key

### Synthetic Mode (Recommended for Evaluation)
```bash
# Open in Xcode
open ARCnet.xcodeproj

# Select "Local (Synthetic)" scheme
# Build flags: USE_SYNTHETIC_FEEDS=1, NO_CONNECTORS=1
# Run on iPad simulator
```

In synthetic mode, all data feeds use bundled JSON files. Only LLM calls require network access.

## Project Structure

```
ARCnet/
├── App/                    # SwiftUI application code
│   ├── Domain/            # Core models and mappings
│   ├── Engine/            # Orchestration and autonomy logic
│   ├── Agents/            # Agent implementations and prompts
│   ├── LLM/               # LLM client abstraction
│   ├── Data/              # Data gateway and synthetic feeds
│   ├── UI/                # Views and ViewModels
│   └── Security/          # Keychain services
├── Ref-Packs/             # Reference data and document manifests
├── docs/                  # Architecture Decision Records
└── Tests/                 # Unit and integration tests
```

## Research Contributions

### Flow Mode Proposal
The [Flow-Mode-Proposal.md](Flow-Mode-Proposal.md) document presents a research design for adaptive agent routing using:
- Embedding-based similarity matching
- Policy-weighted composite scoring
- Region-based specialist clustering
- Handshake strength metrics for output quality

This includes evaluation methodology with defined metrics and A/B testing protocols.

### Autonomy Framework
The system implements a graduated autonomy model:
- **HITL (Human-in-the-Loop)**: Full approval required at each checkpoint
- **HOTL (Human-on-the-Loop)**: Auto-advance with intervention capability
- **Autonomous**: Proceed without prompts (with audit logging)

## Publications & Related Work

This project draws from research in:
- Human-AI teaming and adjustable autonomy
- Multi-agent systems for organizational decision support
- Explainable AI (XAI) in high-stakes domains
- Digital twin architectures for command and control

## License

This project is provided for research and educational purposes.

## Contact

Timothy Moore
GitHub: [@Tmmoore286](https://github.com/Tmmoore286)

