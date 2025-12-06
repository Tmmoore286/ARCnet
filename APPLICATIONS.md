# Industry Applications

ARCnet's core architecture—**data integration, predictive modeling, risk surfacing, and agentic decision support**—is domain-agnostic. This document details how the platform adapts to specific industries through configuration rather than code changes.

---

## Architecture Adaptation Pattern

Each industry deployment requires three configuration layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Domain Configuration                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │ Schema Mapping│  │ Agent Personas│  │ Risk Weights  │       │
│  │ (data model)  │  │ (specialists) │  │ (priorities)  │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Core Platform                                │
│  ETL Engine │ ML Models │ Agent Orchestrator │ NLP │ Vision     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Manufacturing & Industrial Operations

### Use Case
A manufacturing plant needs to optimize production uptime while managing maintenance costs and production schedules.

### Data Sources
| Source Type | Examples | Ingestion Method |
|-------------|----------|------------------|
| Equipment sensors | SCADA, IoT telemetry | API/streaming |
| Maintenance systems | CMMS exports, work orders | Excel/CSV |
| Production schedules | MES, ERP exports | Excel/API |
| Financial data | Cost center reports, budgets | Excel/CSV |
| Quality data | Inspection logs, defect reports | CSV/photos |

### Schema Configuration

```yaml
# configs/manufacturing.yaml

dimensions:
  org_unit:
    source_column: "cost_center"
    display_name: "Production Line"

  asset:
    source_column: "equipment_id"
    attributes:
      - asset_class: "machine_type"
      - location: "cell_location"
      - criticality: "production_impact"

  event:
    source_column: "production_order"
    attributes:
      - event_type: "order_type"  # Production Run, Changeover, Maintenance Window
      - start_date: "scheduled_start"
      - end_date: "scheduled_end"

facts:
  budget_execution:
    table: "fact_cost_tracking"
    measures:
      - budgeted: "planned_cost"
      - actual: "actual_cost"
      - variance: "cost_variance"

  maintenance:
    table: "fact_work_orders"
    measures:
      - labor_hours: "maintenance_hours"
      - parts_cost: "materials_cost"
      - downtime: "equipment_downtime_hrs"

  production:
    table: "fact_production"
    measures:
      - units_produced: "good_units"
      - scrap: "rejected_units"
      - cycle_time: "actual_cycle_time"
```

### Agent Configuration

```yaml
# configs/manufacturing_agents.yaml

specialists:
  - id: "production_planner"
    name: "Production Planning Specialist"
    domain: "production"
    data_access:
      - fact_production
      - dim_event
    prompt_context: |
      You are a production planning expert. Analyze production schedules,
      identify bottlenecks, and assess capacity constraints. Consider
      changeover times, batch sizes, and demand variability.

  - id: "maintenance_engineer"
    name: "Maintenance Engineering Specialist"
    domain: "maintenance"
    data_access:
      - fact_work_orders
      - dim_asset
      - ml_predictions.equipment_failure
    prompt_context: |
      You are a reliability engineer. Analyze equipment health, maintenance
      history, and failure predictions. Prioritize maintenance activities
      based on production impact and cost.

  - id: "plant_controller"
    name: "Plant Controller"
    domain: "finance"
    data_access:
      - fact_cost_tracking
      - dim_org_unit
    prompt_context: |
      You are the plant financial controller. Monitor cost performance,
      identify variances, and forecast spending. Balance maintenance
      investment against production value.
```

### ML Model Configuration

```yaml
# configs/manufacturing_ml.yaml

predictive_maintenance:
  target: "days_to_failure"
  features:
    - operating_hours_since_last_service
    - vibration_trend_7d
    - temperature_anomaly_score
    - age_months
    - failure_history_count
  model: "xgboost_survival"
  prediction_horizons: [7, 14, 30, 90]

production_risk:
  target: "schedule_slip_probability"
  features:
    - equipment_availability_forecast
    - material_availability
    - labor_availability
    - historical_changeover_variance
  model: "gradient_boosted_classifier"
```

### Example Queries
- "Which production lines are at risk for next week's orders?"
- "What is the projected maintenance spend for Q4?"
- "Which machines should we service during the holiday shutdown?"
- "Show me the top 5 equipment reliability risks"

---

## Healthcare Operations

### Use Case
A hospital system needs to optimize OR scheduling, manage medical equipment availability, and forecast departmental budgets.

### Data Sources
| Source Type | Examples | Ingestion Method |
|-------------|----------|------------------|
| Clinical systems | EHR exports, OR schedules | API/HL7 |
| Equipment management | Biomed work orders, PM schedules | Excel/CSV |
| Financial systems | Department budgets, charge data | Excel/CSV |
| Staffing | Scheduling systems, timekeeping | API/CSV |
| Supply chain | Inventory levels, purchase orders | Excel/API |

### Schema Configuration

```yaml
# configs/healthcare.yaml

dimensions:
  org_unit:
    source_column: "department_code"
    display_name: "Department"
    hierarchy:
      - facility
      - service_line
      - department

  asset:
    source_column: "equipment_id"
    attributes:
      - asset_class: "device_type"  # MRI, Ventilator, Infusion Pump
      - location: "unit_location"
      - criticality: "clinical_impact"
      - fda_class: "device_class"

  event:
    source_column: "case_id"
    attributes:
      - event_type: "procedure_type"
      - start_date: "scheduled_datetime"
      - duration: "estimated_duration"
      - surgeon: "primary_surgeon"
      - or_room: "operating_room"

facts:
  budget_execution:
    table: "fact_department_financials"
    measures:
      - budgeted: "approved_budget"
      - actual: "ytd_expenses"
      - revenue: "ytd_revenue"

  maintenance:
    table: "fact_biomed_work_orders"
    measures:
      - labor_hours: "tech_hours"
      - parts_cost: "parts_expense"
      - downtime: "equipment_oos_hours"

  cases:
    table: "fact_surgical_cases"
    measures:
      - case_count: "completed_cases"
      - turnover_time: "room_turnover_minutes"
      - cancellation_rate: "cancelled_cases"
```

### Agent Configuration

```yaml
# configs/healthcare_agents.yaml

specialists:
  - id: "or_coordinator"
    name: "OR Scheduling Coordinator"
    domain: "operations"
    data_access:
      - fact_surgical_cases
      - dim_event
      - dim_asset
    prompt_context: |
      You are an OR scheduling expert. Analyze surgical schedules,
      equipment requirements, and room availability. Identify scheduling
      conflicts and optimization opportunities. Consider surgeon preferences,
      case complexity, and turnover requirements.

  - id: "biomed_manager"
    name: "Biomedical Engineering Manager"
    domain: "maintenance"
    data_access:
      - fact_biomed_work_orders
      - dim_asset
      - ml_predictions.equipment_failure
    prompt_context: |
      You are the biomedical engineering manager. Analyze medical equipment
      reliability, PM compliance, and failure predictions. Prioritize based
      on patient safety impact and regulatory requirements.

  - id: "department_administrator"
    name: "Department Administrator"
    domain: "finance"
    data_access:
      - fact_department_financials
      - dim_org_unit
    prompt_context: |
      You are a healthcare financial administrator. Monitor department
      budgets, analyze expense trends, and forecast financial performance.
      Consider reimbursement patterns and volume trends.

  - id: "nursing_director"
    name: "Nursing Director"
    domain: "personnel"
    data_access:
      - fact_staffing
      - dim_org_unit
    prompt_context: |
      You are the nursing director. Analyze staffing levels, skill mix,
      and scheduling patterns. Identify coverage gaps and overtime trends.
```

### ML Model Configuration

```yaml
# configs/healthcare_ml.yaml

equipment_availability:
  target: "available_for_scheduled_case"
  features:
    - pm_compliance_score
    - days_since_last_failure
    - device_age_years
    - utilization_rate_30d
    - pending_repair_orders
  model: "xgboost_classifier"

case_cancellation_risk:
  target: "will_cancel"
  features:
    - patient_comorbidity_score
    - equipment_availability_forecast
    - surgeon_historical_cancel_rate
    - days_until_procedure
    - pre_op_clearance_status
  model: "gradient_boosted_classifier"

budget_forecast:
  target: "monthly_expense"
  features:
    - case_volume_forecast
    - seasonal_adjustment
    - supply_cost_trend
    - labor_cost_trend
  model: "sarimax"
```

### Example Queries
- "Which surgeries this week are at risk due to equipment availability?"
- "What is the projected ICU budget variance for the quarter?"
- "Which devices should be prioritized for preventive maintenance?"
- "Show me OR utilization trends and cancellation patterns"

---

## Construction & Project Management

### Use Case
A general contractor managing multiple construction projects needs to predict equipment needs, track project costs, and optimize resource allocation across job sites.

### Data Sources
| Source Type | Examples | Ingestion Method |
|-------------|----------|------------------|
| Project management | Primavera, MS Project exports | Excel/CSV |
| Equipment tracking | GPS/telematics, rental invoices | API/CSV |
| Financial systems | Job cost reports, change orders | Excel/CSV |
| Subcontractor data | Invoices, schedules | Excel/CSV |
| Site documentation | Progress photos, inspection reports | Photos/PDF |

### Schema Configuration

```yaml
# configs/construction.yaml

dimensions:
  org_unit:
    source_column: "job_number"
    display_name: "Project"
    hierarchy:
      - region
      - project
      - phase

  asset:
    source_column: "equipment_id"
    attributes:
      - asset_class: "equipment_type"  # Crane, Excavator, Loader
      - ownership: "owned_or_rented"
      - location: "current_jobsite"

  event:
    source_column: "activity_id"
    attributes:
      - event_type: "activity_type"
      - start_date: "planned_start"
      - end_date: "planned_finish"
      - critical_path: "is_critical"

facts:
  budget_execution:
    table: "fact_job_cost"
    measures:
      - budgeted: "original_budget"
      - committed: "committed_cost"
      - actual: "actual_cost"
      - forecast: "estimated_at_completion"

  equipment:
    table: "fact_equipment_usage"
    measures:
      - hours: "operating_hours"
      - fuel: "fuel_consumed"
      - idle_time: "idle_hours"
      - utilization: "utilization_rate"

  schedule:
    table: "fact_schedule_progress"
    measures:
      - planned_pct: "baseline_percent_complete"
      - actual_pct: "actual_percent_complete"
      - variance_days: "schedule_variance"
```

### Agent Configuration

```yaml
# configs/construction_agents.yaml

specialists:
  - id: "project_manager"
    name: "Project Manager"
    domain: "operations"
    data_access:
      - fact_schedule_progress
      - dim_event
      - ml_predictions.schedule_risk
    prompt_context: |
      You are a senior project manager. Analyze schedule performance,
      identify critical path risks, and assess resource constraints.
      Consider weather impacts, subcontractor dependencies, and
      inspection requirements.

  - id: "equipment_manager"
    name: "Equipment Manager"
    domain: "logistics"
    data_access:
      - fact_equipment_usage
      - dim_asset
      - ml_predictions.equipment_failure
    prompt_context: |
      You are the equipment fleet manager. Optimize equipment allocation
      across job sites, predict maintenance needs, and manage rental
      decisions. Consider mobilization costs and utilization rates.

  - id: "project_accountant"
    name: "Project Accountant"
    domain: "finance"
    data_access:
      - fact_job_cost
      - dim_org_unit
    prompt_context: |
      You are a construction project accountant. Monitor job costs,
      analyze change order impacts, and forecast final project cost.
      Identify cost overruns early and recommend corrective actions.
```

### Vision Module Configuration

```yaml
# configs/construction_vision.yaml

site_progress:
  model: "construction_progress_cnn"
  inputs:
    - drone_imagery
    - progress_photos
  outputs:
    - percent_complete_estimate
    - activity_detection
    - safety_compliance_flags

document_extraction:
  model: "construction_ocr"
  document_types:
    - daily_reports
    - inspection_forms
    - delivery_tickets
```

### Example Queries
- "Which projects are at risk of missing their milestone?"
- "Where should we reallocate the tower crane next month?"
- "What is our projected cost overrun across all active jobs?"
- "Show me equipment utilization by job site"

---

## Fleet & Logistics

### Use Case
A delivery company needs to predict vehicle maintenance needs, optimize routes, and manage fleet costs across multiple distribution centers.

### Data Sources
| Source Type | Examples | Ingestion Method |
|-------------|----------|------------------|
| Telematics | GPS, engine diagnostics | API/streaming |
| Maintenance | Shop work orders, parts inventory | Excel/CSV |
| Operations | Route plans, delivery logs | API/CSV |
| Financial | Fuel costs, lease payments | Excel/CSV |
| Driver data | HOS logs, inspection reports | API/photos |

### Schema Configuration

```yaml
# configs/fleet.yaml

dimensions:
  org_unit:
    source_column: "location_code"
    display_name: "Distribution Center"

  asset:
    source_column: "vehicle_id"
    attributes:
      - asset_class: "vehicle_type"  # Tractor, Trailer, Van
      - make_model: "vehicle_make_model"
      - model_year: "year"
      - mileage: "current_odometer"

  event:
    source_column: "route_id"
    attributes:
      - event_type: "route_type"
      - date: "dispatch_date"
      - stops: "stop_count"

facts:
  maintenance:
    table: "fact_shop_work_orders"
    measures:
      - labor_hours: "mechanic_hours"
      - parts_cost: "parts_total"
      - downtime: "vehicle_oos_days"

  operations:
    table: "fact_route_performance"
    measures:
      - miles: "total_miles"
      - fuel: "fuel_gallons"
      - stops: "completed_stops"
      - on_time_pct: "on_time_delivery_rate"

  costs:
    table: "fact_vehicle_costs"
    measures:
      - fuel_cost: "fuel_expense"
      - maintenance_cost: "maintenance_expense"
      - lease_cost: "lease_payment"
```

### Agent Configuration

```yaml
# configs/fleet_agents.yaml

specialists:
  - id: "dispatch_supervisor"
    name: "Dispatch Operations Supervisor"
    domain: "operations"
    data_access:
      - fact_route_performance
      - dim_event
      - ml_predictions.vehicle_availability
    prompt_context: |
      You are the dispatch operations supervisor. Optimize route
      assignments, manage driver schedules, and ensure delivery
      commitments are met. Consider HOS regulations, customer
      time windows, and vehicle capabilities.

  - id: "fleet_maintenance"
    name: "Fleet Maintenance Manager"
    domain: "maintenance"
    data_access:
      - fact_shop_work_orders
      - dim_asset
      - ml_predictions.breakdown_risk
    prompt_context: |
      You are the fleet maintenance manager. Predict vehicle failures,
      schedule preventive maintenance, and manage parts inventory.
      Minimize unplanned breakdowns while controlling maintenance costs.

  - id: "fleet_controller"
    name: "Fleet Financial Controller"
    domain: "finance"
    data_access:
      - fact_vehicle_costs
      - dim_org_unit
    prompt_context: |
      You are the fleet financial controller. Analyze total cost of
      ownership, compare owned vs leased economics, and optimize
      fleet size. Monitor fuel efficiency and identify cost reduction
      opportunities.
```

### ML Model Configuration

```yaml
# configs/fleet_ml.yaml

breakdown_prediction:
  target: "breakdown_within_7_days"
  features:
    - miles_since_last_service
    - engine_fault_code_count
    - oil_life_remaining
    - brake_wear_indicator
    - tire_pressure_variance
    - ambient_temperature_exposure
  model: "xgboost_classifier"

route_optimization:
  objective: "minimize_total_cost"
  constraints:
    - hos_compliance
    - time_windows
    - vehicle_capacity
  model: "rl_routing_agent"
```

### Vision Module Configuration

```yaml
# configs/fleet_vision.yaml

damage_assessment:
  model: "vehicle_damage_classifier"
  inputs:
    - driver_submitted_photos
    - dock_camera_footage
  outputs:
    - damage_detected: boolean
    - severity: [minor, moderate, severe]
    - damage_type: [dent, scratch, crack, structural]
    - estimated_repair_cost: float
```

### Example Queries
- "Which vehicles should we service this weekend to avoid Monday breakdowns?"
- "What is our projected fuel cost variance for the quarter?"
- "Show me breakdown trends by vehicle age and mileage"
- "Which distribution center has the highest maintenance cost per mile?"

---

## Energy & Utilities

### Use Case
An electric utility needs to predict equipment failures, optimize maintenance crew scheduling, and manage capital project portfolios.

### Data Sources
| Source Type | Examples | Ingestion Method |
|-------------|----------|------------------|
| SCADA/DMS | Real-time grid data | API/streaming |
| Asset management | Equipment records, inspection history | Excel/CSV |
| Outage management | OMS data, trouble reports | API/CSV |
| Financial | Capital budgets, O&M costs | Excel/CSV |
| Inspection | Drone imagery, thermography | Photos |

### Schema Configuration

```yaml
# configs/utility.yaml

dimensions:
  org_unit:
    source_column: "district_code"
    display_name: "Service District"
    hierarchy:
      - region
      - district
      - substation

  asset:
    source_column: "equipment_id"
    attributes:
      - asset_class: "equipment_type"  # Transformer, Breaker, Line
      - voltage_class: "voltage_level"
      - install_date: "in_service_date"
      - condition: "asset_health_index"

  event:
    source_column: "work_order_id"
    attributes:
      - event_type: "work_type"  # PM, Corrective, Capital
      - priority: "work_priority"
      - scheduled_date: "planned_date"

facts:
  reliability:
    table: "fact_outage_events"
    measures:
      - customer_interruptions: "customers_affected"
      - duration_minutes: "outage_duration"
      - saidi_contribution: "saidi_minutes"
      - saifi_contribution: "saifi_count"

  maintenance:
    table: "fact_work_orders"
    measures:
      - labor_hours: "crew_hours"
      - material_cost: "materials_expense"
      - contractor_cost: "contractor_expense"

  capital:
    table: "fact_capital_projects"
    measures:
      - budget: "approved_budget"
      - spent: "actual_spend"
      - forecast: "forecast_at_completion"
```

### Agent Configuration

```yaml
# configs/utility_agents.yaml

specialists:
  - id: "grid_operations"
    name: "Grid Operations Engineer"
    domain: "operations"
    data_access:
      - fact_outage_events
      - dim_asset
      - ml_predictions.failure_probability
    prompt_context: |
      You are a grid operations engineer. Analyze equipment health,
      predict failures, and assess reliability impacts. Consider
      load patterns, weather exposure, and system configuration.

  - id: "maintenance_planner"
    name: "Maintenance Planning Supervisor"
    domain: "maintenance"
    data_access:
      - fact_work_orders
      - dim_event
      - ml_predictions.equipment_condition
    prompt_context: |
      You are the maintenance planning supervisor. Optimize crew
      scheduling, prioritize work orders, and manage contractor
      resources. Balance preventive and corrective maintenance
      to maximize reliability within budget.

  - id: "capital_manager"
    name: "Capital Program Manager"
    domain: "finance"
    data_access:
      - fact_capital_projects
      - dim_org_unit
    prompt_context: |
      You are the capital program manager. Track project execution,
      forecast spending, and prioritize investments based on risk
      and reliability impact. Consider regulatory requirements
      and rate case implications.
```

### Vision Module Configuration

```yaml
# configs/utility_vision.yaml

aerial_inspection:
  model: "powerline_defect_detector"
  inputs:
    - drone_imagery
    - helicopter_patrol_video
  outputs:
    - defects_detected: list
    - defect_severity: [low, medium, high, critical]
    - component_affected: string
    - gps_location: coordinates

thermal_analysis:
  model: "thermal_anomaly_detector"
  inputs:
    - infrared_images
  outputs:
    - hotspots_detected: list
    - temperature_delta: float
    - failure_risk_score: float
```

### RL Optimization Configuration

```yaml
# configs/utility_rl.yaml

crew_scheduling:
  environment: "crew_dispatch_env"
  state_space:
    - pending_work_orders
    - crew_locations
    - travel_times
    - work_priorities
  action_space: "discrete_assignment"
  reward_function:
    - minimize_travel_time: 0.3
    - maximize_priority_completion: 0.4
    - balance_crew_workload: 0.2
    - minimize_overtime: 0.1

maintenance_prioritization:
  environment: "asset_maintenance_env"
  state_space:
    - equipment_health_indices
    - failure_probabilities
    - budget_remaining
    - reliability_metrics
  action_space: "ranking"
  reward_function:
    - maximize_reliability: 0.5
    - minimize_cost: 0.3
    - regulatory_compliance: 0.2
```

### Example Queries
- "Which transformers are at highest risk of failure this summer?"
- "What is our projected SAIDI impact from deferred maintenance?"
- "Optimize crew assignments for tomorrow's planned work"
- "Show me capital project spending variance by district"

---

## Adapting to New Industries

To deploy ARCnet in a new industry:

### 1. Define Schema Mapping
Map your data sources to the canonical dimensional model:
- Identify organizational hierarchy (dim_org_unit)
- Define asset taxonomy (dim_asset)
- Characterize events/activities (dim_event)
- Specify fact tables and measures

### 2. Configure Agent Personas
Define specialist agents for your domain:
- Identify key decision-making roles
- Specify data access permissions
- Write domain-specific prompt context
- Configure autonomy levels

### 3. Train/Adapt ML Models
Configure prediction targets and features:
- Define prediction objectives (classification, regression, time-to-event)
- Identify available features from your data
- Select appropriate model architectures
- Configure prediction horizons and thresholds

### 4. Customize Vision Modules (if applicable)
- Identify visual data sources (documents, photos, video)
- Select or train appropriate models
- Configure extraction pipelines

### 5. Define Risk Weights
Configure how different factors contribute to overall risk:
- Operational impact weights
- Financial impact weights
- Regulatory/compliance weights
- Safety/criticality weights

---

## Configuration File Structure

```
configs/
├── {industry}/
│   ├── schema.yaml           # Data model mapping
│   ├── agents.yaml           # Agent personas and prompts
│   ├── ml.yaml               # ML model configurations
│   ├── vision.yaml           # Vision module settings
│   ├── rl.yaml               # RL optimization settings
│   ├── risk_weights.yaml     # Risk scoring configuration
│   └── etl_mappings/         # File-type specific column mappings
│       ├── budget_report.yaml
│       ├── maintenance_log.yaml
│       └── schedule_export.yaml
```

The platform loads configuration at startup, enabling the same codebase to serve multiple industries without modification.
