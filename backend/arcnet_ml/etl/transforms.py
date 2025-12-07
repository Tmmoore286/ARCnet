"""Feature transformation and engineering for ARCnet ML models."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

import numpy as np
import pandas as pd


@dataclass
class FeatureConfig:
    """Configuration for feature engineering."""

    # Rolling window sizes (in days)
    rolling_windows: list[int] = None  # type: ignore

    # Lag periods (in days)
    lag_periods: list[int] = None  # type: ignore

    # Target horizon (days ahead to predict)
    target_horizon: int = 14

    def __post_init__(self) -> None:
        if self.rolling_windows is None:
            self.rolling_windows = [7, 14, 30]
        if self.lag_periods is None:
            self.lag_periods = [7, 14, 30]


class FeatureTransformer:
    """Transforms raw data into ML-ready features."""

    def __init__(self, config: FeatureConfig | None = None) -> None:
        self.config = config or FeatureConfig()

    def add_calendar_features(self, df: pd.DataFrame, date_col: str) -> pd.DataFrame:
        """Add calendar-based features from a date column."""
        df = df.copy()
        dates = pd.to_datetime(df[date_col])

        # Basic calendar features
        df["day_of_week"] = dates.dt.dayofweek
        df["day_of_month"] = dates.dt.day
        df["month"] = dates.dt.month
        df["quarter"] = dates.dt.quarter
        df["year"] = dates.dt.year

        # Fiscal year features (FY starts Oct 1)
        df["fiscal_year"] = dates.apply(
            lambda d: d.year + 1 if d.month >= 10 else d.year
        )
        df["fiscal_quarter"] = dates.apply(
            lambda d: ((d.month - 10) % 12) // 3 + 1
        )
        df["fiscal_month"] = dates.apply(
            lambda d: ((d.month - 10) % 12) + 1
        )

        # Cyclical encoding for month (sin/cos)
        df["month_sin"] = np.sin(2 * np.pi * dates.dt.month / 12)
        df["month_cos"] = np.cos(2 * np.pi * dates.dt.month / 12)

        # Weekend indicator
        df["is_weekend"] = dates.dt.dayofweek >= 5

        return df

    def add_rolling_features(
        self,
        df: pd.DataFrame,
        value_col: str,
        group_cols: list[str],
        date_col: str = "snapshot_date",
    ) -> pd.DataFrame:
        """Add rolling window statistics."""
        df = df.copy()
        df = df.sort_values([*group_cols, date_col])

        for window in self.config.rolling_windows:
            # Rolling mean
            df[f"{value_col}_rolling_{window}d_mean"] = df.groupby(group_cols)[
                value_col
            ].transform(lambda x: x.rolling(window, min_periods=1).mean())

            # Rolling std
            df[f"{value_col}_rolling_{window}d_std"] = df.groupby(group_cols)[
                value_col
            ].transform(lambda x: x.rolling(window, min_periods=1).std())

            # Rolling min/max
            df[f"{value_col}_rolling_{window}d_min"] = df.groupby(group_cols)[
                value_col
            ].transform(lambda x: x.rolling(window, min_periods=1).min())

            df[f"{value_col}_rolling_{window}d_max"] = df.groupby(group_cols)[
                value_col
            ].transform(lambda x: x.rolling(window, min_periods=1).max())

        return df

    def add_lag_features(
        self,
        df: pd.DataFrame,
        value_col: str,
        group_cols: list[str],
        date_col: str = "snapshot_date",
    ) -> pd.DataFrame:
        """Add lagged values as features."""
        df = df.copy()
        df = df.sort_values([*group_cols, date_col])

        for lag in self.config.lag_periods:
            df[f"{value_col}_lag_{lag}d"] = df.groupby(group_cols)[
                value_col
            ].shift(lag)

        return df

    def add_target(
        self,
        df: pd.DataFrame,
        value_col: str,
        group_cols: list[str],
        date_col: str = "snapshot_date",
    ) -> pd.DataFrame:
        """Add future target value for supervised learning."""
        df = df.copy()
        df = df.sort_values([*group_cols, date_col])

        # Shift backwards to get future value
        df[f"{value_col}_target"] = df.groupby(group_cols)[value_col].shift(
            -self.config.target_horizon
        )

        return df

    def add_maintenance_features(
        self,
        readiness_df: pd.DataFrame,
        maintenance_df: pd.DataFrame,
    ) -> pd.DataFrame:
        """Add maintenance-derived features to readiness data."""
        readiness = readiness_df.copy()
        maint = maintenance_df.copy()

        # Ensure date types
        readiness["snapshot_date"] = pd.to_datetime(readiness["snapshot_date"])
        maint["start_date"] = pd.to_datetime(maint["start_date"])
        maint["end_date"] = pd.to_datetime(maint["end_date"])

        # Count recent maintenance events per platform
        def count_recent_events(row: pd.Series, lookback_days: int = 30) -> int:
            cutoff = row["snapshot_date"] - pd.Timedelta(days=lookback_days)
            recent = maint[
                (maint["platform_id"] == row["platform_id"])
                & (maint["start_date"] >= cutoff)
                & (maint["start_date"] <= row["snapshot_date"])
            ]
            return len(recent)

        readiness["maint_events_30d"] = readiness.apply(
            lambda r: count_recent_events(r, 30), axis=1
        )

        # Calculate downtime days in last 30 days
        def sum_downtime(row: pd.Series, lookback_days: int = 30) -> int:
            cutoff = row["snapshot_date"] - pd.Timedelta(days=lookback_days)
            recent = maint[
                (maint["platform_id"] == row["platform_id"])
                & (maint["end_date"] >= cutoff)
                & (maint["start_date"] <= row["snapshot_date"])
            ]
            return recent["downtime_days"].sum() if len(recent) > 0 else 0

        readiness["downtime_30d"] = readiness.apply(
            lambda r: sum_downtime(r, 30), axis=1
        )

        return readiness

    def add_teep_features(
        self,
        readiness_df: pd.DataFrame,
        teep_df: pd.DataFrame,
    ) -> pd.DataFrame:
        """Add TEEP event proximity features."""
        readiness = readiness_df.copy()
        teep = teep_df.copy()

        readiness["snapshot_date"] = pd.to_datetime(readiness["snapshot_date"])
        teep["start_date"] = pd.to_datetime(teep["start_date"])

        def count_upcoming_events(row: pd.Series, lookahead_days: int = 30) -> int:
            horizon = row["snapshot_date"] + pd.Timedelta(days=lookahead_days)
            upcoming = teep[
                (teep["unit_id"] == row["unit_id"])
                & (teep["start_date"] > row["snapshot_date"])
                & (teep["start_date"] <= horizon)
            ]
            return len(upcoming)

        def has_critical_event(row: pd.Series, lookahead_days: int = 14) -> bool:
            horizon = row["snapshot_date"] + pd.Timedelta(days=lookahead_days)
            critical = teep[
                (teep["unit_id"] == row["unit_id"])
                & (teep["start_date"] > row["snapshot_date"])
                & (teep["start_date"] <= horizon)
                & (teep["priority"] == "Critical")
            ]
            return len(critical) > 0

        readiness["teep_events_30d"] = readiness.apply(
            lambda r: count_upcoming_events(r, 30), axis=1
        )
        readiness["critical_event_14d"] = readiness.apply(
            lambda r: has_critical_event(r, 14), axis=1
        )

        return readiness

    def prepare_maintenance_features(
        self,
        readiness_df: pd.DataFrame,
        maintenance_df: pd.DataFrame | None = None,
        teep_df: pd.DataFrame | None = None,
    ) -> pd.DataFrame:
        """Full feature engineering pipeline for maintenance forecasting."""
        df = readiness_df.copy()

        # Calendar features
        df = self.add_calendar_features(df, "snapshot_date")

        # Rolling and lag features on availability
        df = self.add_rolling_features(
            df, "availability_pct", ["platform_id"], "snapshot_date"
        )
        df = self.add_lag_features(
            df, "availability_pct", ["platform_id"], "snapshot_date"
        )

        # Maintenance-derived features
        if maintenance_df is not None:
            df = self.add_maintenance_features(df, maintenance_df)

        # TEEP features
        if teep_df is not None:
            df = self.add_teep_features(df, teep_df)

        # Target variable
        df = self.add_target(df, "availability_pct", ["platform_id"], "snapshot_date")

        return df

    def get_feature_columns(self, df: pd.DataFrame) -> list[str]:
        """Get list of feature columns (excluding identifiers and target)."""
        exclude_patterns = [
            "_id",
            "_target",
            "snapshot_date",
            "unit_name",
            "platform_type",
            "status",
            "serial_number",
        ]

        feature_cols = []
        for col in df.columns:
            if any(pattern in col.lower() for pattern in exclude_patterns):
                continue
            if df[col].dtype in (np.float64, np.int64, np.bool_):
                feature_cols.append(col)

        return feature_cols
