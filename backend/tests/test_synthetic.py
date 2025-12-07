"""Tests for synthetic data generation."""

import pandas as pd
import pytest

from arcnet_ml.data.synthetic import SyntheticConfig, SyntheticDataGenerator


class TestSyntheticDataGenerator:
    """Tests for SyntheticDataGenerator."""

    def test_generate_all_returns_expected_datasets(self) -> None:
        """Should generate all expected dataset types."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        expected_keys = {"units", "platforms", "maintenance", "budget", "teep", "readiness"}
        assert set(datasets.keys()) == expected_keys

    def test_generate_all_returns_dataframes(self) -> None:
        """Should return pandas DataFrames."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        for name, df in datasets.items():
            assert isinstance(df, pd.DataFrame), f"{name} should be a DataFrame"

    def test_units_have_expected_columns(self) -> None:
        """Units should have required columns."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        required_cols = {"unit_id", "unit_name", "parent_command", "location"}
        assert required_cols.issubset(set(datasets["units"].columns))

    def test_platforms_linked_to_units(self) -> None:
        """All platforms should reference valid units."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        unit_ids = set(datasets["units"]["unit_id"])
        platform_unit_ids = set(datasets["platforms"]["unit_id"])

        assert platform_unit_ids.issubset(unit_ids)

    def test_maintenance_linked_to_platforms(self) -> None:
        """All maintenance records should reference valid platforms."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        platform_ids = set(datasets["platforms"]["platform_id"])
        maint_platform_ids = set(datasets["maintenance"]["platform_id"])

        assert maint_platform_ids.issubset(platform_ids)

    def test_budget_has_fiscal_year_data(self) -> None:
        """Budget should contain fiscal year information."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        budget = datasets["budget"]
        assert "fiscal_year" in budget.columns
        assert "fiscal_month" in budget.columns
        assert "execution_rate" in budget.columns

    def test_readiness_snapshots_have_availability(self) -> None:
        """Readiness snapshots should have availability percentages."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        readiness = datasets["readiness"]
        assert "availability_pct" in readiness.columns
        assert readiness["availability_pct"].between(0, 1).all()

    def test_custom_config_affects_output(self) -> None:
        """Custom config should change generated data."""
        config = SyntheticConfig(num_units=2, seed=123)
        generator = SyntheticDataGenerator(config)
        datasets = generator.generate_all()

        assert len(datasets["units"]) == 2

    def test_seed_produces_reproducible_results(self) -> None:
        """Same seed should produce identical data."""
        config = SyntheticConfig(seed=42)

        gen1 = SyntheticDataGenerator(config)
        gen2 = SyntheticDataGenerator(config)

        data1 = gen1.generate_all()
        data2 = gen2.generate_all()

        pd.testing.assert_frame_equal(data1["units"], data2["units"])
        pd.testing.assert_frame_equal(data1["platforms"], data2["platforms"])

    def test_teep_events_have_required_fields(self) -> None:
        """TEEP events should have scheduling and resource fields."""
        generator = SyntheticDataGenerator()
        datasets = generator.generate_all()

        teep = datasets["teep"]
        required_cols = {
            "event_id",
            "unit_id",
            "event_type",
            "start_date",
            "end_date",
            "personnel_required",
            "priority",
        }
        assert required_cols.issubset(set(teep.columns))
