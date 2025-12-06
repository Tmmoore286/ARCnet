# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Git Commit Authorship

**IMPORTANT**: Never include `Co-Authored-By` lines in commit messages. Tim Moore is the sole author of all commits. Do not add any AI attribution, co-author tags, or signatures to commits.

## Project Overview

ARCnet is an Agentic Decision Support System - an iPad application exploring human-AI collaboration in complex decision-making environments. Built with Swift using a modular package architecture.

## Architecture

- **ARCnetDomain**: Core domain models (Mission, Checkpoint, COA, Gate policies)
- **ARCnetData**: Data layer with repositories and feed types
- **ARCnetAgents**: Multi-agent system (Scribe, Coordinator, Specialists, Integrator, Evaluator, Tasking)
- **ARCnetLLM**: LLM integration layer
- **ARCnetEngine**: Pipeline orchestration, COA tournament, gate enforcement

## Common Commands

```bash
swift build          # Build all packages
swift test           # Run all tests
swift package clean  # Clean build artifacts
```

## Key Concepts

- **MCPP Phases**: problem_framing, coa_dev, coa_compare, orders
- **Gates A-D**: Decision checkpoints requiring approval based on autonomy mode
- **Autonomy Modes**: HITL (human-in-the-loop), HOTL (human-on-the-loop), AUTO
- **Flow Modes**: Org (hierarchical), Mesh (capability-based), Hybrid
