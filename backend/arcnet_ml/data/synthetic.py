"""Synthetic data generation for ARCnet ML development.

Generates realistic maintenance, budget, and readiness data patterns
for model development and testing without requiring real operational data.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Any

import numpy as np
import pandas as pd


@dataclass
class SyntheticConfig:
    """Configuration for synthetic data generation."""

    # Time range
    start_date: date = field(default_factory=lambda: date(2023, 1, 1))
    end_date: date = field(default_factory=lambda: date(2024, 12, 31))

    # Organizational structure
    num_units: int = 5
    platforms_per_unit: tuple[int, int] = (8, 15)  # min, max

    # Platform characteristics
    platform_types: list[str] = field(
        default_factory=lambda: ["HMMWV", "MTVR", "LAV", "AAV", "M1A1"]
    )
    age_range_months: tuple[int, int] = (12, 180)

    # Maintenance patterns
    base_availability: float = 0.85
    availability_std: float = 0.08
    seasonal_dip_q4: float = 0.05  # Q4 maintenance surge
    age_degradation_per_year: float = 0.005
    failure_rate_per_week: float = 0.08
    parts_delay_probability: float = 0.30
    parts_delay_days: tuple[int, int] = (7, 21)

    # Budget patterns
    annual_budget_range: tuple[int, int] = (500_000, 2_000_000)
    execution_curve_steepness: float = 2.5  # S-curve parameter
    quarterly_variance: float = 0.08
    maintenance_budget_correlation: float = 0.6

    # TEEP events
    major_events_per_quarter: tuple[int, int] = (3, 6)
    event_duration_days: tuple[int, int] = (3, 14)
    personnel_requirement: tuple[int, int] = (10, 60)

    # Random seed for reproducibility
    seed: int = 42


class SyntheticDataGenerator:
    """Generates synthetic operational data for ARCnet ML development."""

    def __init__(self, config: SyntheticConfig | None = None) -> None:
        self.config = config or SyntheticConfig()
        self._rng = np.random.default_rng(self.config.seed)
        random.seed(self.config.seed)

    def generate_all(self) -> dict[str, pd.DataFrame]:
        """Generate all synthetic datasets."""
        units = self._generate_units()
        platforms = self._generate_platforms(units)
        maintenance = self._generate_maintenance_logs(platforms)
        budget = self._generate_budget_data(units)
        teep = self._generate_teep_events(units)
        readiness = self._generate_readiness_snapshots(platforms, maintenance)

        return {
            "units": units,
            "platforms": platforms,
            "maintenance": maintenance,
            "budget": budget,
            "teep": teep,
            "readiness": readiness,
        }

    def _generate_units(self) -> pd.DataFrame:
        """Generate organizational units."""
        unit_names = [
            "1st Maintenance Bn",
            "2nd Supply Bn",
            "3rd Motor Transport Bn",
            "4th Landing Support Bn",
            "Combat Logistics Regiment",
        ]
        units = []
        for i in range(self.config.num_units):
            units.append({
                "unit_id": f"UNIT-{i + 1:03d}",
                "unit_name": unit_names[i] if i < len(unit_names) else f"Unit {i + 1}",
                "parent_command": "1st MLG",
                "location": random.choice(["Camp Pendleton", "Camp Lejeune", "Okinawa"]),
            })
        return pd.DataFrame(units)

    def _generate_platforms(self, units: pd.DataFrame) -> pd.DataFrame:
        """Generate equipment platforms for each unit."""
        platforms = []
        platform_id = 1

        for _, unit in units.iterrows():
            num_platforms = self._rng.integers(
                self.config.platforms_per_unit[0],
                self.config.platforms_per_unit[1] + 1,
            )
            for _ in range(num_platforms):
                platform_type = random.choice(self.config.platform_types)
                age_months = self._rng.integers(
                    self.config.age_range_months[0],
                    self.config.age_range_months[1] + 1,
                )
                platforms.append({
                    "platform_id": f"PLT-{platform_id:05d}",
                    "unit_id": unit["unit_id"],
                    "platform_type": platform_type,
                    "age_months": int(age_months),
                    "acquisition_date": (
                        self.config.start_date - timedelta(days=int(age_months) * 30)
                    ).isoformat(),
                    "serial_number": f"{platform_type[:3]}-{self._rng.integers(10000, 99999)}",
                })
                platform_id += 1

        return pd.DataFrame(platforms)

    def _generate_maintenance_logs(self, platforms: pd.DataFrame) -> pd.DataFrame:
        """Generate maintenance event logs."""
        logs = []
        log_id = 1

        date_range = pd.date_range(
            self.config.start_date, self.config.end_date, freq="D"
        )

        maintenance_categories = [
            ("Scheduled", 0.5),
            ("Unscheduled", 0.3),
            ("Battle Damage", 0.05),
            ("Parts Delay", 0.15),
        ]
        categories, weights = zip(*maintenance_categories)

        for _, platform in platforms.iterrows():
            # Determine failure events based on Poisson process
            expected_failures = len(date_range) / 7 * self.config.failure_rate_per_week
            num_events = self._rng.poisson(expected_failures)

            if num_events == 0:
                continue

            # Sample event dates
            event_indices = self._rng.choice(len(date_range), size=num_events, replace=False)
            event_dates = sorted([date_range[i] for i in event_indices])

            for event_date in event_dates:
                category = random.choices(categories, weights=weights)[0]

                # Downtime duration based on category
                if category == "Scheduled":
                    downtime_days = self._rng.integers(1, 4)
                elif category == "Parts Delay":
                    downtime_days = self._rng.integers(
                        self.config.parts_delay_days[0],
                        self.config.parts_delay_days[1] + 1,
                    )
                elif category == "Battle Damage":
                    downtime_days = self._rng.integers(14, 45)
                else:  # Unscheduled
                    downtime_days = self._rng.integers(2, 10)

                end_date = event_date + timedelta(days=int(downtime_days))

                logs.append({
                    "log_id": f"MAINT-{log_id:06d}",
                    "platform_id": platform["platform_id"],
                    "unit_id": platform["unit_id"],
                    "category": category,
                    "start_date": event_date.date().isoformat(),
                    "end_date": end_date.date().isoformat(),
                    "downtime_days": int(downtime_days),
                    "parts_required": category in ("Unscheduled", "Parts Delay", "Battle Damage"),
                    "labor_hours": int(downtime_days * self._rng.uniform(4, 12)),
                    "cost_estimate": int(downtime_days * self._rng.uniform(500, 3000)),
                })
                log_id += 1

        return pd.DataFrame(logs)

    def _generate_budget_data(self, units: pd.DataFrame) -> pd.DataFrame:
        """Generate budget execution data with S-curve spending pattern."""
        budget_records = []

        appropriations = ["O&M", "Procurement", "RDT&E"]
        fiscal_year_start = date(self.config.start_date.year, 10, 1)  # FY starts Oct 1

        for _, unit in units.iterrows():
            for appropriation in appropriations:
                # Annual budget varies by appropriation type
                if appropriation == "O&M":
                    annual_budget = self._rng.integers(
                        self.config.annual_budget_range[0],
                        self.config.annual_budget_range[1],
                    )
                elif appropriation == "Procurement":
                    annual_budget = self._rng.integers(
                        self.config.annual_budget_range[0] // 2,
                        self.config.annual_budget_range[1] // 2,
                    )
                else:
                    annual_budget = self._rng.integers(
                        self.config.annual_budget_range[0] // 4,
                        self.config.annual_budget_range[1] // 4,
                    )

                # Generate monthly execution following S-curve
                for month_offset in range(24):  # 2 fiscal years
                    record_date = fiscal_year_start + timedelta(days=month_offset * 30)
                    if record_date > self.config.end_date:
                        break

                    fiscal_month = (month_offset % 12) + 1  # 1-12 within FY

                    # S-curve execution: slow start, ramp up, year-end push
                    x = fiscal_month / 12
                    base_cumulative = 1 / (
                        1 + np.exp(-self.config.execution_curve_steepness * (x - 0.5))
                    )

                    # Add quarterly variance
                    quarter = (fiscal_month - 1) // 3 + 1
                    quarterly_adjustment = self._rng.normal(0, self.config.quarterly_variance)

                    cumulative_rate = np.clip(base_cumulative + quarterly_adjustment, 0, 1)
                    executed = int(annual_budget * cumulative_rate)
                    planned = int(annual_budget * (fiscal_month / 12))

                    budget_records.append({
                        "unit_id": unit["unit_id"],
                        "appropriation": appropriation,
                        "fiscal_year": record_date.year if record_date.month >= 10 else record_date.year - 1,
                        "fiscal_month": fiscal_month,
                        "record_date": record_date.isoformat(),
                        "planned_ytd": planned,
                        "executed_ytd": executed,
                        "remaining": annual_budget - executed,
                        "annual_budget": int(annual_budget),
                        "execution_rate": round(executed / annual_budget, 4),
                    })

        return pd.DataFrame(budget_records)

    def _generate_teep_events(self, units: pd.DataFrame) -> pd.DataFrame:
        """Generate Training and Exercise Employment Plan events."""
        events = []
        event_id = 1

        event_types = [
            "Field Exercise",
            "Live Fire",
            "Combined Arms",
            "Deployment",
            "Inspection",
            "Certification",
        ]

        # Generate by quarter
        current_date = self.config.start_date
        while current_date < self.config.end_date:
            quarter_end = current_date + timedelta(days=90)

            for _, unit in units.iterrows():
                num_events = self._rng.integers(
                    self.config.major_events_per_quarter[0],
                    self.config.major_events_per_quarter[1] + 1,
                )

                for _ in range(num_events):
                    event_date = current_date + timedelta(
                        days=int(self._rng.integers(0, 90))
                    )
                    if event_date > self.config.end_date:
                        continue

                    duration = self._rng.integers(
                        self.config.event_duration_days[0],
                        self.config.event_duration_days[1] + 1,
                    )
                    personnel = self._rng.integers(
                        self.config.personnel_requirement[0],
                        self.config.personnel_requirement[1] + 1,
                    )

                    events.append({
                        "event_id": f"TEEP-{event_id:05d}",
                        "unit_id": unit["unit_id"],
                        "event_type": random.choice(event_types),
                        "start_date": event_date.isoformat(),
                        "end_date": (event_date + timedelta(days=int(duration))).isoformat(),
                        "duration_days": int(duration),
                        "personnel_required": int(personnel),
                        "platforms_required": int(self._rng.integers(3, 15)),
                        "priority": random.choice(["Critical", "High", "Medium"]),
                        "no_degrade": random.random() < 0.3,  # 30% are no-degrade
                    })
                    event_id += 1

            current_date = quarter_end

        return pd.DataFrame(events)

    def _generate_readiness_snapshots(
        self, platforms: pd.DataFrame, maintenance: pd.DataFrame
    ) -> pd.DataFrame:
        """Generate weekly readiness snapshots."""
        snapshots = []

        # Weekly snapshots
        date_range = pd.date_range(
            self.config.start_date, self.config.end_date, freq="W"
        )

        # Pre-compute maintenance periods for faster lookup
        maint_df = maintenance.copy()
        maint_df["start_date"] = pd.to_datetime(maint_df["start_date"])
        maint_df["end_date"] = pd.to_datetime(maint_df["end_date"])

        for snapshot_date in date_range:
            for _, platform in platforms.iterrows():
                # Check if platform is in maintenance
                in_maintenance = maint_df[
                    (maint_df["platform_id"] == platform["platform_id"])
                    & (maint_df["start_date"] <= snapshot_date)
                    & (maint_df["end_date"] >= snapshot_date)
                ]

                if len(in_maintenance) > 0:
                    availability = 0.0
                    status = "NMC"  # Not Mission Capable
                else:
                    # Base availability with age and seasonal effects
                    age_years = platform["age_months"] / 12
                    age_penalty = age_years * self.config.age_degradation_per_year

                    # Q4 seasonal dip (fiscal year end maintenance surge)
                    month = snapshot_date.month
                    seasonal_penalty = (
                        self.config.seasonal_dip_q4 if month in [7, 8, 9] else 0
                    )

                    availability = np.clip(
                        self.config.base_availability
                        - age_penalty
                        - seasonal_penalty
                        + self._rng.normal(0, self.config.availability_std),
                        0.0,
                        1.0,
                    )
                    status = "FMC" if availability > 0.9 else "PMC"  # Partially MC

                snapshots.append({
                    "snapshot_date": snapshot_date.date().isoformat(),
                    "platform_id": platform["platform_id"],
                    "unit_id": platform["unit_id"],
                    "platform_type": platform["platform_type"],
                    "availability_pct": round(float(availability), 4),
                    "status": status,
                    "age_months": platform["age_months"],
                })

        return pd.DataFrame(snapshots)

    def save_to_csv(self, output_dir: str) -> dict[str, str]:
        """Generate all data and save to CSV files."""
        from pathlib import Path

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        datasets = self.generate_all()
        file_paths = {}

        for name, df in datasets.items():
            file_path = output_path / f"{name}.csv"
            df.to_csv(file_path, index=False)
            file_paths[name] = str(file_path)

        return file_paths


def generate_synthetic_data(
    output_dir: str = "data/synthetic",
    config: SyntheticConfig | None = None,
) -> dict[str, str]:
    """Convenience function to generate and save synthetic data."""
    generator = SyntheticDataGenerator(config)
    return generator.save_to_csv(output_dir)


if __name__ == "__main__":
    # Generate sample data when run directly
    import sys
    from pathlib import Path

    output_dir = sys.argv[1] if len(sys.argv) > 1 else "data/synthetic"

    print(f"Generating synthetic data to {output_dir}...")
    paths = generate_synthetic_data(output_dir)

    for name, path in paths.items():
        df = pd.read_csv(path)
        print(f"  {name}: {len(df)} records -> {path}")
