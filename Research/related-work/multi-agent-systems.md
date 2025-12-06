# Multi-Agent Systems: Literature Positioning

## Overview

Multi-Agent Systems (MAS) research addresses coordination, communication, and collaboration among autonomous agents. ARCnet extends MAS patterns with semantic routing and organizational grounding.

---

## Classical MAS Foundations

### Wooldridge (2009) - Introduction to MultiAgent Systems

**Key concepts**:
- Agent autonomy, reactivity, proactivity, social ability
- Coordination mechanisms: cooperation, competition, negotiation
- Communication protocols (FIPA ACL, KQML)

**Relevance to ARCnet**: ARCnet agents exhibit all four properties; coordination is structured by organizational hierarchy rather than emergent negotiation.

### Contract Net Protocol (Smith, 1980)

**Mechanism**: Task announcement → bidding → awarding → execution

**Comparison to ARCnet**:

| Aspect | Contract Net | ARCnet |
|--------|--------------|--------|
| Task allocation | Bidding by agents | Semantic similarity scoring |
| Selection criteria | Bid evaluation | Composite score + diversity |
| Overhead | N announcements + N bids | Single embedding comparison pass |

ARCnet's approach is more computationally efficient—no bidding round required.

---

## LLM-Based Agent Frameworks

### AutoGen (Microsoft, 2023)

**Architecture**: Conversational agents with customizable interaction patterns.

**Routing**: LLM-based selection or sequential/broadcast patterns.

**Comparison to ARCnet**:

| Aspect | AutoGen | ARCnet |
|--------|---------|--------|
| Routing | LLM decides or hardcoded | Semantic similarity |
| Cost | High (LLM call for routing) | Low (embedding comparison) |
| Determinism | Non-deterministic | Deterministic |
| Governance | Manual | First-class constraint |

### CrewAI (2024)

**Architecture**: Role-based agents with defined tasks and tools.

**Routing**: Process types (sequential, hierarchical) determine flow.

**Comparison to ARCnet**:

| Aspect | CrewAI | ARCnet |
|--------|--------|--------|
| Expert selection | Predefined roles | Dynamic similarity-based |
| Diversity | None | Explicit penalty |
| Flexibility | Fixed crew composition | Mission-adaptive activation |

### LangGraph (LangChain, 2024)

**Architecture**: Graph-based state machines for agent workflows.

**Routing**: Conditional edges based on state or LLM output.

**Comparison to ARCnet**:

| Aspect | LangGraph | ARCnet |
|--------|-----------|--------|
| Flow control | Graph edges | Orchestrator + gates |
| Expert selection | Node definitions | Semantic routing |
| Auditability | State history | Checkpoint ledger |

---

## Organizational Multi-Agent Systems

### OMACS (DeLoach, 2007)

**Key idea**: Agents organized into roles within organizational structure; capabilities matched to goals.

**Relevance to ARCnet**: Similar organizational grounding, but ARCnet uses embedding similarity rather than explicit capability ontologies.

### MOISE+ (Hubner et al., 2002)

**Key idea**: Separate structural, functional, and deontic specifications for agent organizations.

**Relevance to ARCnet**: ARCnet's three modes (Org, Mesh, Hybrid) align with structural vs. functional organization dimensions.

---

## ARCnet's Contribution to MAS Literature

### Semantic Similarity as Coordination Mechanism

Traditional MAS coordination relies on:
- Explicit capability declarations
- Bidding/auction protocols
- Message passing

ARCnet introduces semantic similarity in embedding space as coordination primitive:
- No explicit capability ontology required
- No communication overhead for task allocation
- Graceful handling of novel tasks (generalization via embeddings)

### Diversity-Aware Team Formation

Classical team formation optimizes for capability coverage. ARCnet adds explicit diversity:

$$A^* = \arg\max \left[ \sum_i S(i) - \lambda \sum_{i<j} \cos(\mathbf{v}_i, \mathbf{v}_j) \right]$$

This prevents "groupthink" in agent teams—a known failure mode in MAS.

### Hybrid Organizational Modes

ARCnet's three modes (Org/Mesh/Hybrid) enable systematic study of:
- When does hierarchical structure help?
- When does capability-based routing outperform?
- How should they be combined?

---

## Open Questions

1. **Emergent coordination**: Can agents learn to improve routing based on outcomes?
2. **Conflict resolution**: How should agents handle contradictory assessments?
3. **Scalability**: How does performance degrade with hundreds of agents?

---

## References

- Wooldridge, M. (2009). An Introduction to MultiAgent Systems. Wiley.
- Smith, R. G. (1980). The contract net protocol. *IEEE Transactions on Computers*.
- Wu, Q., et al. (2023). AutoGen: Enabling next-gen LLM applications. *arXiv preprint*.
- DeLoach, S. A., & Garcia-Ojeda, J. C. (2010). O-MaSE: A customizable approach to designing and building complex, adaptive multi-agent systems. *IJAOSE*.
- Hubner, J. F., Sichman, J. S., & Boissier, O. (2002). MOISE+: Towards a structural, functional, and deontic model for MAS organization. *AAMAS*.
