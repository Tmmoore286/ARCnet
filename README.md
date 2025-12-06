# ARCnet

**Adaptive Reasoning and Collaboration Network**

A predictive operations intelligence platform that integrates siloed data sources, applies machine learning for forecasting, and provides AI-powered decision support through a multi-agent architecture.

---

## Abstract

Modern organizations struggle with fragmented data across financial systems, maintenance records, operational schedules, and asset inventories. Decision-makers receive delayed, incomplete pictures of organizational readiness—often discovering problems at execution time rather than during planning.

**ARCnet** addresses this by creating an **Operational Digital Twin**: a unified system that ingests disparate data sources, predicts future states using machine learning, surfaces risks proactively, and provides AI agents that reason transparently about complex decisions.

The system implements:

- **Automated ETL pipelines** that normalize heterogeneous data (Excel, CSV, API exports) into a unified analytical warehouse
- **Predictive ML models** for maintenance forecasting, budget burn-rate analysis, and operational risk scoring
- **Multi-agent orchestration** where specialized AI agents collaborate through structured workflows with human oversight
- **Natural language interfaces** for querying complex operational data
- **Computer vision modules** for document OCR and visual inspection
- **Reinforcement learning optimizers** for resource allocation and scheduling

The result is a system that transforms reactive decision-making into predictive, evidence-based operations management.

---

## Architecture

```
                                    ┌─────────────────────────────────────┐
                                    │         Presentation Layer          │
                                    │  ┌─────────┐ ┌─────────┐ ┌────────┐ │
                                    │  │ iPad App│ │Dashboard│ │  API   │ │
                                    │  └────┬────┘ └────┬────┘ └───┬────┘ │
                                    └───────┼──────────┼───────────┼──────┘
                                            │          │           │
                    ┌───────────────────────┴──────────┴───────────┴───────────────────────┐
                    │                        Agent Orchestration Layer                      │
                    │  ┌──────────────────────────────────────────────────────────────────┐ │
                    │  │   Scribe → Coordinator → Specialists → Integrator → Evaluator   │ │
                    │  │                              │                                   │ │
                    │  │            ┌─────────────────┼─────────────────┐                 │ │
                    │  │            ▼                 ▼                 ▼                 │ │
                    │  │      [Operations]      [Logistics]       [Finance]              │ │
                    │  │                                                                  │ │
                    │  │   Human-in-the-Loop ◄──► Checkpoints ◄──► Audit Trail           │ │
                    │  └──────────────────────────────────────────────────────────────────┘ │
                    └───────────────────────────────────────────────────────────────────────┘
                                                        │
                    ┌───────────────────────────────────┴───────────────────────────────────┐
                    │                          Intelligence Layer                           │
                    │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │
                    │  │ Predictive     │  │ Budget/Burn    │  │ Readiness      │          │
                    │  │ Maintenance    │  │ Rate Forecast  │  │ Risk Scoring   │          │
                    │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘          │
                    │          │                   │                   │                    │
                    │  ┌───────┴───────────────────┴───────────────────┴───────┐           │
                    │  │              ML Inference Engine                       │           │
                    │  │   XGBoost │ Time-Series │ Risk Ensemble │ RL Optimizer │           │
                    │  └───────────────────────────────────────────────────────┘           │
                    └───────────────────────────────────────────────────────────────────────┘
                                                        │
                    ┌───────────────────────────────────┴───────────────────────────────────┐
                    │                           Data Layer                                  │
                    │  ┌─────────────────────────────────────────────────────────────────┐  │
                    │  │                    Analytical Warehouse                         │  │
                    │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │  │
                    │  │  │ dim_org_unit │  │ dim_asset    │  │ dim_event    │          │  │
                    │  │  └──────────────┘  └──────────────┘  └──────────────┘          │  │
                    │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │  │
                    │  │  │ fact_budget  │  │ fact_maint   │  │ fact_orders  │          │  │
                    │  │  └──────────────┘  └──────────────┘  └──────────────┘          │  │
                    │  └─────────────────────────────────────────────────────────────────┘  │
                    └───────────────────────────────────────────────────────────────────────┘
                                                        ▲
                    ┌───────────────────────────────────┴───────────────────────────────────┐
                    │                           ETL Pipeline                                │
                    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
                    │  │ File Detect │→ │ Column Map  │→ │ Staging     │→ │ Transform   │  │
                    │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
                    │         ▲                                                             │
                    │         │                                                             │
                    │  ┌──────┴──────────────────────────────────────────────────────────┐  │
                    │  │  Excel │ CSV │ Scanned Documents (OCR) │ API Exports │ Photos   │  │
                    │  └─────────────────────────────────────────────────────────────────┘  │
                    └───────────────────────────────────────────────────────────────────────┘
```

---

## Core Capabilities

### 1. Data Engineering Pipeline

**Problem:** Organizations maintain critical data in disconnected spreadsheets, legacy systems, and manual reports with inconsistent formats.

**Solution:** Automated ETL pipeline that:
- Detects file types via filename patterns and header inspection
- Maps heterogeneous column names to canonical schema
- Loads raw data into staging tables (all TEXT to prevent import errors)
- Transforms and validates into dimensional model (facts + dimensions)
- Maintains full lineage and audit trail

```
Data Sources                    Staging Layer              Analytical Warehouse
┌──────────────┐               ┌──────────────┐           ┌──────────────────────┐
│ Budget.xlsx  │──┐            │ stg_budget   │           │ dim_org_unit         │
├──────────────┤  │            ├──────────────┤           │ dim_asset            │
│ Maint_Log.csv│──┼──[Detect]──│ stg_maint    │──[Transform]─│ dim_event         │
├──────────────┤  │            ├──────────────┤           │ fact_budget_execution│
│ Schedule.xlsx│──┘            │ stg_events   │           │ fact_maintenance     │
└──────────────┘               └──────────────┘           │ fact_work_orders     │
                                                          └──────────────────────┘
```

**Technical Implementation:**
- Python-based ingestion with pandas for file parsing
- Configuration-driven column mapping (new file formats require config only, not code)
- PostgreSQL warehouse with star schema design
- Incremental loading with change detection
- Data quality scoring and anomaly flagging

---

### 2. Predictive Machine Learning Models

#### Predictive Maintenance

**Problem:** Equipment failures discovered at execution time cause costly delays and cancellations.

**Solution:** ML models trained on historical maintenance patterns to forecast:
- Probability of asset failure within specified time windows
- Expected downtime duration
- Parts demand forecasting
- Optimal maintenance scheduling

**Approach:**
- Gradient boosted trees (XGBoost/LightGBM) for failure classification
- Survival analysis for time-to-failure estimation
- Feature engineering from work order history, usage metrics, age, and environmental factors
- Calibrated probability outputs for risk-based decision making

#### Budget Forecasting

**Problem:** Budget execution deviations discovered too late to correct, leading to shortfalls or underspend.

**Solution:** Time-series models that predict:
- Burn rate trajectories by organizational unit
- End-of-period fund availability
- Anomaly detection for unexpected spending patterns
- Sensitivity analysis for scenario planning

**Approach:**
- SARIMAX for seasonality-aware forecasting
- Prophet-style decomposition for trend/holiday effects
- Ensemble with gradient boosted regressors for non-linear patterns
- Confidence intervals for risk quantification

#### Readiness Risk Scoring

**Problem:** Multiple interdependent factors (equipment, budget, personnel) combine to create operational risk that's difficult to assess holistically.

**Solution:** Composite risk model that:
- Integrates predictions from maintenance and budget models
- Weights factors by operational impact
- Produces interpretable risk scores with causal attribution
- Ranks events/operations by risk for prioritization

---

### 3. Multi-Agent Decision Orchestration

**Problem:** Complex decisions require synthesizing information across multiple domains (operations, logistics, finance), but expertise is siloed.

**Solution:** Coordinated AI agents that mirror organizational structure:

```
Mission Input
     │
     ▼
┌─────────┐    Refines mission statement, extracts constraints
│ Scribe  │    and acceptance criteria
└────┬────┘
     │
     ▼
┌─────────────┐    Routes to appropriate specialist agents
│ Coordinator │    based on domain requirements
└──────┬──────┘
       │
       ├──────────────┬──────────────┐
       ▼              ▼              ▼
┌────────────┐ ┌────────────┐ ┌────────────┐
│ Operations │ │ Logistics  │ │  Finance   │    Domain experts gather
│ Specialist │ │ Specialist │ │ Specialist │    relevant data and analysis
└─────┬──────┘ └─────┬──────┘ └─────┬──────┘
      │              │              │
      └──────────────┼──────────────┘
                     ▼
              ┌────────────┐    Synthesizes findings into
              │ Integrator │    coherent assessment
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐    Evaluates complexity, determines
              │ Evaluator  │    if multiple options needed
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐    Generates and scores
              │    COA     │    alternative approaches
              │ Generator  │
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐
              │  Approval  │◄── Human Decision Point
              │    Gate    │
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐    Produces actionable
              │  Tasking   │    implementation plan
              └────────────┘
```

**Key Features:**
- **Configurable Autonomy**: Each agent can operate in Human-in-the-Loop (approval required), Human-on-the-Loop (auto-advance with intervention capability), or Autonomous mode
- **Explainable Checkpoints**: Every stage produces auditable output with rationale, evidence citations, and confidence scores
- **Evidence Linking**: All conclusions cite source documents with section-level granularity
- **Audit Trail**: Complete JSONL logging for post-hoc analysis and compliance

---

### 4. Natural Language Interface

**Problem:** Complex queries against operational data require SQL expertise and understanding of data model.

**Solution:** Text-to-SQL capability that:
- Translates natural language questions into warehouse queries
- Returns results with narrative explanation
- Supports follow-up questions with context retention

**Example Queries:**
- "Which scheduled events are at risk due to equipment availability?"
- "What is the projected budget shortfall for Q4 by department?"
- "Which assets should we prioritize for preventive maintenance?"

---

### 5. Computer Vision Module

**Problem:** Critical data exists in scanned documents, photos, and legacy printouts that can't be directly ingested.

**Solution:** Vision capabilities for:
- **Document OCR**: Extract structured data from scanned reports and forms
- **Visual Inspection**: Classify damage severity from equipment photos
- **Dashboard Parsing**: Extract metrics from screenshots of legacy systems

**Approach:**
- Transformer-based OCR (TrOCR) for text extraction
- Table detection and structure recognition for tabular data
- CNN-based damage classification trained on domain-specific imagery
- Integration with ETL pipeline for seamless data flow

---

### 6. Reinforcement Learning Optimization

**Problem:** Resource allocation and scheduling involve complex trade-offs that are difficult to optimize manually.

**Solution:** RL agents that learn optimal policies for:
- **Resource Allocation**: Distribute limited resources across organizational units to maximize overall readiness
- **Schedule Optimization**: Sequence events to minimize conflicts and risk
- **COA Ranking**: Learn decision preferences from historical outcomes

**Approach:**
- Policy gradient methods (PPO) for continuous action spaces
- Multi-objective reward shaping for competing goals
- Simulation environment for safe policy training
- Human feedback integration for preference alignment

---

## Applications

ARCnet's architecture is domain-agnostic. The core pattern—**integrate data, predict future state, surface risks, recommend actions**—applies across industries.

### Defense & Government
- Command decision support with transparent AI reasoning
- Readiness forecasting across equipment, personnel, and funding
- Training and exercise planning optimization
- Automated staff product generation

### Manufacturing & Industrial
- Predictive maintenance for production equipment
- Production schedule optimization
- Supply chain risk assessment
- Quality control with visual inspection

### Healthcare
- Medical equipment availability forecasting
- Operating room scheduling optimization
- Department budget tracking and forecasting
- Clinical resource allocation

### Construction & Engineering
- Heavy equipment maintenance prediction
- Project schedule risk assessment
- Subcontractor and resource optimization
- Site progress monitoring via imagery

### Fleet & Logistics
- Vehicle breakdown prediction
- Route and load optimization
- Maintenance scheduling for minimal disruption
- Damage assessment from driver-submitted photos

### Energy & Utilities
- Grid equipment failure prediction
- Maintenance crew scheduling
- Capital project tracking
- Infrastructure inspection via drone imagery

See [APPLICATIONS.md](APPLICATIONS.md) for detailed industry configurations.

---

## Technical Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Swift 6, SwiftUI, Combine, SceneKit, Swift Charts |
| **Backend** | Python 3.11+, FastAPI |
| **ML/AI** | PyTorch, XGBoost, scikit-learn, Hugging Face Transformers |
| **Database** | PostgreSQL 15+ with TimescaleDB extension |
| **ETL** | pandas, SQLAlchemy, Apache Airflow (optional) |
| **LLM** | Protocol-based abstraction (OpenAI, Anthropic, local models) |
| **Vision** | OpenCV, TrOCR, YOLO |
| **RL** | Stable Baselines3, Gymnasium |

---

## Repository Structure

```
ARCnet/
├── ios-app/                      # Swift iPad application
│   ├── App/
│   │   ├── Domain/               # Core models and types
│   │   ├── Engine/               # Orchestration and autonomy
│   │   ├── Agents/               # Agent implementations
│   │   ├── LLM/                  # LLM client abstraction
│   │   ├── Data/                 # Data gateway and feeds
│   │   ├── UI/                   # SwiftUI views
│   │   └── Security/             # Keychain services
│   └── Tests/
│
├── backend/                      # Python services
│   ├── etl/                      # Data ingestion pipeline
│   │   ├── ingestion/            # File detection and loading
│   │   ├── transforms/           # Staging to warehouse
│   │   └── configs/              # File type mappings
│   │
│   ├── ml/                       # Machine learning models
│   │   ├── predictive_maint/     # Equipment failure prediction
│   │   ├── budget_forecast/      # Burn-rate modeling
│   │   ├── readiness_risk/       # Composite risk scoring
│   │   └── training/             # Model training pipelines
│   │
│   ├── nlp/                      # Natural language processing
│   │   ├── text_to_sql/          # Query translation
│   │   └── summarization/        # Report generation
│   │
│   ├── vision/                   # Computer vision
│   │   ├── ocr/                  # Document extraction
│   │   └── inspection/           # Visual classification
│   │
│   ├── rl/                       # Reinforcement learning
│   │   ├── allocator/            # Resource optimization
│   │   └── scheduler/            # Event sequencing
│   │
│   └── api/                      # REST API endpoints
│
├── database/                     # PostgreSQL schema
│   ├── migrations/
│   └── seeds/
│
├── notebooks/                    # Research and analysis
│   ├── eda/                      # Exploratory data analysis
│   ├── model_dev/                # Model development
│   └── math/                     # Mathematical foundations
│
└── docs/                         # Documentation
    ├── architecture/
    ├── research/
    └── deployment/
```

---

## Key Design Principles

### 1. Explainability First
Every AI output includes rationale, evidence citations, and confidence scores. No black-box decisions.

### 2. Human Oversight
Configurable autonomy levels ensure humans remain in control. Full audit trails for accountability.

### 3. Domain Agnostic Core
Business logic is configuration, not code. Adapting to new industries requires schema mapping, not rewrites.

### 4. Graceful Degradation
System operates with partial data. ML models provide uncertainty quantification. Missing inputs are flagged, not fatal.

### 5. Security by Design
Secrets in secure storage (Keychain). Encryption at rest. Role-based access. Audit logging.

---

## Getting Started

### Prerequisites
- Xcode 16+ (Swift 6) for iOS app
- Python 3.11+ for backend services
- PostgreSQL 15+ for data warehouse
- OpenAI API key (or compatible LLM endpoint)

### Quick Start (Synthetic Mode)

The system can run entirely with synthetic data for evaluation:

```bash
# Clone repository
git clone https://github.com/[username]/ARCnet.git
cd ARCnet

# iOS App (synthetic mode)
open ios-app/ARCnet.xcodeproj
# Select "Local (Synthetic)" scheme
# Build and run on iPad simulator

# Backend (optional, for full ML pipeline)
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m api.main
```

See [docs/deployment/](docs/deployment/) for production setup.

---

## Research Contributions

This project explores several research areas:

### Human-AI Teaming
- Graduated autonomy models (HITL → HOTL → Autonomous)
- Intervention mechanisms that preserve human agency
- Trust calibration through transparent reasoning

### Multi-Agent Coordination
- Structured workflows for organizational decision processes
- Specialist agent collaboration patterns
- Consensus and conflict resolution mechanisms

### Predictive Operations
- Transfer learning for maintenance prediction across asset types
- Multi-horizon budget forecasting with uncertainty quantification
- Composite risk scoring with causal attribution

### Explainable AI
- Evidence-linked reasoning chains
- Checkpoint-based decision auditing
- Natural language rationale generation

---

## Publications & Related Work

This project builds on research in:
- Human-AI teaming and adjustable autonomy
- Multi-agent systems for organizational decision support
- Predictive maintenance and remaining useful life estimation
- Explainable AI (XAI) in high-stakes domains
- Digital twin architectures

---

## License

This project is provided for research and educational purposes.

---

## Contact

**Timothy Moore**
GitHub: [@Tmmoore286](https://github.com/Tmmoore286)

---

## Documentation Index

| Document | Description |
|----------|-------------|
| [APPLICATIONS.md](APPLICATIONS.md) | Industry-specific configurations and use cases |
| [ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) | Detailed system design |
| [Canonical-OVERVIEW.md](Canonical-OVERVIEW.md) | Product specification |
| [CODEX.md](CODEX.md) | Technical implementation guide |
| [AGENTS.md](AGENTS.md) | Agent development patterns |
