"""Data ingestion and file detection for ARCnet ML pipeline."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd
import yaml


@dataclass
class FileTypeConfig:
    """Configuration for a recognized file type."""

    pattern: str  # Regex pattern for filename matching
    file_type: str  # Internal type identifier
    column_map: dict[str, str]  # source_col -> canonical_col
    date_columns: list[str]  # Columns to parse as dates
    required_columns: list[str]  # Must be present after mapping


class DataIngester:
    """Handles file detection, loading, and initial validation."""

    DEFAULT_CONFIGS = {
        "maintenance": FileTypeConfig(
            pattern=r"(?i)(maint|maintenance|repair).*\.(csv|xlsx?)$",
            file_type="maintenance",
            column_map={
                "platform": "platform_id",
                "platform_id": "platform_id",
                "equipment": "platform_id",
                "category": "category",
                "type": "category",
                "start": "start_date",
                "start_date": "start_date",
                "end": "end_date",
                "end_date": "end_date",
                "downtime": "downtime_days",
                "days": "downtime_days",
                "cost": "cost_estimate",
            },
            date_columns=["start_date", "end_date"],
            required_columns=["platform_id", "start_date"],
        ),
        "budget": FileTypeConfig(
            pattern=r"(?i)(budget|funds?|execution|spend).*\.(csv|xlsx?)$",
            file_type="budget",
            column_map={
                "unit": "unit_id",
                "unit_id": "unit_id",
                "organization": "unit_id",
                "appropriation": "appropriation",
                "appn": "appropriation",
                "fiscal_year": "fiscal_year",
                "fy": "fiscal_year",
                "planned": "planned_ytd",
                "executed": "executed_ytd",
                "remaining": "remaining",
                "annual": "annual_budget",
                "total": "annual_budget",
            },
            date_columns=["record_date"],
            required_columns=["unit_id", "appropriation"],
        ),
        "readiness": FileTypeConfig(
            pattern=r"(?i)(readiness|availability|status).*\.(csv|xlsx?)$",
            file_type="readiness",
            column_map={
                "date": "snapshot_date",
                "snapshot_date": "snapshot_date",
                "platform": "platform_id",
                "platform_id": "platform_id",
                "availability": "availability_pct",
                "avail": "availability_pct",
                "pct": "availability_pct",
                "status": "status",
                "unit": "unit_id",
                "unit_id": "unit_id",
            },
            date_columns=["snapshot_date"],
            required_columns=["platform_id", "availability_pct"],
        ),
        "teep": FileTypeConfig(
            pattern=r"(?i)(teep|training|event|exercise).*\.(csv|xlsx?)$",
            file_type="teep",
            column_map={
                "event": "event_id",
                "event_id": "event_id",
                "unit": "unit_id",
                "unit_id": "unit_id",
                "type": "event_type",
                "event_type": "event_type",
                "start": "start_date",
                "start_date": "start_date",
                "end": "end_date",
                "end_date": "end_date",
                "personnel": "personnel_required",
                "platforms": "platforms_required",
                "priority": "priority",
            },
            date_columns=["start_date", "end_date"],
            required_columns=["unit_id", "start_date"],
        ),
    }

    def __init__(
        self,
        config_path: str | Path | None = None,
        custom_configs: dict[str, FileTypeConfig] | None = None,
    ) -> None:
        """Initialize ingester with optional custom configurations."""
        self.configs = self.DEFAULT_CONFIGS.copy()

        if config_path:
            self._load_config_file(Path(config_path))

        if custom_configs:
            self.configs.update(custom_configs)

    def _load_config_file(self, config_path: Path) -> None:
        """Load additional configurations from YAML file."""
        if not config_path.exists():
            return

        with open(config_path) as f:
            yaml_config = yaml.safe_load(f)

        for name, cfg in yaml_config.get("file_types", {}).items():
            self.configs[name] = FileTypeConfig(
                pattern=cfg["pattern"],
                file_type=cfg.get("file_type", name),
                column_map=cfg.get("column_map", {}),
                date_columns=cfg.get("date_columns", []),
                required_columns=cfg.get("required_columns", []),
            )

    def detect_file_type(self, file_path: str | Path) -> str | None:
        """Detect the type of a data file based on filename patterns."""
        filename = Path(file_path).name

        for type_name, config in self.configs.items():
            if re.match(config.pattern, filename):
                return type_name

        return None

    def load_file(self, file_path: str | Path) -> pd.DataFrame:
        """Load a file into a DataFrame, detecting format from extension."""
        path = Path(file_path)

        if path.suffix.lower() == ".csv":
            return pd.read_csv(path)
        elif path.suffix.lower() in (".xls", ".xlsx"):
            return pd.read_excel(path)
        else:
            raise ValueError(f"Unsupported file format: {path.suffix}")

    def normalize_columns(
        self, df: pd.DataFrame, file_type: str
    ) -> pd.DataFrame:
        """Map source columns to canonical schema."""
        if file_type not in self.configs:
            return df

        config = self.configs[file_type]

        # Lowercase all column names for matching
        df.columns = [str(c).lower().strip() for c in df.columns]

        # Apply column mapping
        rename_map = {}
        for source_col, target_col in config.column_map.items():
            source_lower = source_col.lower()
            if source_lower in df.columns:
                rename_map[source_lower] = target_col

        df = df.rename(columns=rename_map)

        # Parse date columns
        for date_col in config.date_columns:
            if date_col in df.columns:
                df[date_col] = pd.to_datetime(df[date_col], errors="coerce")

        return df

    def validate(self, df: pd.DataFrame, file_type: str) -> list[str]:
        """Validate a DataFrame against required columns. Returns list of errors."""
        errors = []

        if file_type not in self.configs:
            return errors

        config = self.configs[file_type]

        for req_col in config.required_columns:
            if req_col not in df.columns:
                errors.append(f"Missing required column: {req_col}")

        return errors

    def ingest(self, file_path: str | Path) -> tuple[pd.DataFrame, str, list[str]]:
        """Full ingestion pipeline: load, detect type, normalize, validate.

        Returns:
            Tuple of (DataFrame, detected_type, validation_errors)
        """
        path = Path(file_path)

        # Detect type
        file_type = self.detect_file_type(path)
        if file_type is None:
            file_type = "unknown"

        # Load file
        df = self.load_file(path)

        # Normalize if we know the type
        if file_type != "unknown":
            df = self.normalize_columns(df, file_type)

        # Validate
        errors = self.validate(df, file_type)

        return df, file_type, errors

    def ingest_directory(
        self, dir_path: str | Path
    ) -> dict[str, tuple[pd.DataFrame, list[str]]]:
        """Ingest all recognized files from a directory.

        Returns:
            Dict mapping file_type -> (combined_DataFrame, all_errors)
        """
        dir_path = Path(dir_path)
        results: dict[str, list[tuple[pd.DataFrame, list[str]]]] = {}

        for file_path in dir_path.iterdir():
            if not file_path.is_file():
                continue

            if file_path.suffix.lower() not in (".csv", ".xls", ".xlsx"):
                continue

            try:
                df, file_type, errors = self.ingest(file_path)
                if file_type not in results:
                    results[file_type] = []
                results[file_type].append((df, errors))
            except Exception as e:
                # Log but don't fail on individual files
                print(f"Warning: Failed to ingest {file_path}: {e}")

        # Combine DataFrames by type
        combined: dict[str, tuple[pd.DataFrame, list[str]]] = {}
        for file_type, dfs_and_errors in results.items():
            dfs = [item[0] for item in dfs_and_errors]
            all_errors = [err for item in dfs_and_errors for err in item[1]]

            if dfs:
                combined_df = pd.concat(dfs, ignore_index=True)
                combined[file_type] = (combined_df, all_errors)

        return combined
