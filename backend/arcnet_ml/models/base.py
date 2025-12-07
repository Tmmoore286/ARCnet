"""Base classes for ARCnet ML forecasters."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd


@dataclass
class ForecastResult:
    """Result from a forecasting model."""

    prediction: float
    confidence: float
    lower_bound: float
    upper_bound: float
    feature_importance: dict[str, float] = field(default_factory=dict)
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "prediction": self.prediction,
            "confidence": self.confidence,
            "lower_bound": self.lower_bound,
            "upper_bound": self.upper_bound,
            "feature_importance": self.feature_importance,
            "metadata": self.metadata,
        }


@dataclass
class ModelMetadata:
    """Metadata about a trained model."""

    model_name: str
    version: str
    trained_at: datetime
    training_samples: int
    feature_columns: list[str]
    target_column: str
    metrics: dict[str, float]
    hyperparameters: dict[str, Any]


class BaseForecaster(ABC):
    """Abstract base class for all ARCnet forecasters."""

    def __init__(self, model_name: str = "base") -> None:
        self.model_name = model_name
        self.model: Any = None
        self.feature_columns: list[str] = []
        self.target_column: str = ""
        self.metadata: ModelMetadata | None = None
        self._is_trained = False

    @property
    def is_trained(self) -> bool:
        """Check if model has been trained."""
        return self._is_trained

    @abstractmethod
    def train(
        self,
        X: pd.DataFrame,
        y: pd.Series,
        validation_split: float = 0.2,
    ) -> dict[str, float]:
        """Train the model on data.

        Args:
            X: Feature DataFrame
            y: Target Series
            validation_split: Fraction of data for validation

        Returns:
            Dictionary of evaluation metrics
        """
        pass

    @abstractmethod
    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """Generate point predictions.

        Args:
            X: Feature DataFrame

        Returns:
            Array of predictions
        """
        pass

    @abstractmethod
    def predict_with_confidence(
        self, X: pd.DataFrame, confidence_level: float = 0.9
    ) -> list[ForecastResult]:
        """Generate predictions with confidence intervals.

        Args:
            X: Feature DataFrame
            confidence_level: Confidence level for intervals (0-1)

        Returns:
            List of ForecastResult objects
        """
        pass

    def get_feature_importance(self) -> dict[str, float]:
        """Get feature importance scores."""
        if not self._is_trained:
            return {}

        if hasattr(self.model, "feature_importances_"):
            importances = self.model.feature_importances_
            return dict(zip(self.feature_columns, importances))

        return {}

    def save(self, path: str | Path) -> None:
        """Save model to disk."""
        import joblib

        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)

        model_data = {
            "model": self.model,
            "feature_columns": self.feature_columns,
            "target_column": self.target_column,
            "metadata": self.metadata,
            "model_name": self.model_name,
        }
        joblib.dump(model_data, path)

    def load(self, path: str | Path) -> None:
        """Load model from disk."""
        import joblib

        path = Path(path)
        model_data = joblib.load(path)

        self.model = model_data["model"]
        self.feature_columns = model_data["feature_columns"]
        self.target_column = model_data["target_column"]
        self.metadata = model_data["metadata"]
        self.model_name = model_data["model_name"]
        self._is_trained = True

    def _calculate_metrics(
        self, y_true: np.ndarray, y_pred: np.ndarray
    ) -> dict[str, float]:
        """Calculate standard regression metrics."""
        from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

        mae = mean_absolute_error(y_true, y_pred)
        rmse = np.sqrt(mean_squared_error(y_true, y_pred))
        r2 = r2_score(y_true, y_pred)

        # MAPE (avoid division by zero)
        mask = y_true != 0
        mape = np.mean(np.abs((y_true[mask] - y_pred[mask]) / y_true[mask])) * 100

        return {
            "mae": float(mae),
            "rmse": float(rmse),
            "r2": float(r2),
            "mape": float(mape),
        }
