"""Maintenance availability forecasting model using XGBoost."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

import numpy as np
import pandas as pd
from sklearn.model_selection import TimeSeriesSplit, cross_val_score

from arcnet_ml.models.base import BaseForecaster, ForecastResult, ModelMetadata


@dataclass
class MaintenanceModelConfig:
    """Configuration for maintenance forecaster."""

    # XGBoost hyperparameters
    n_estimators: int = 100
    max_depth: int = 6
    learning_rate: float = 0.1
    min_child_weight: int = 3
    subsample: float = 0.8
    colsample_bytree: float = 0.8

    # Training settings
    early_stopping_rounds: int = 10
    cv_folds: int = 5

    # Prediction settings
    quantiles: tuple[float, float] = (0.1, 0.9)  # For confidence intervals


class MaintenanceForecaster(BaseForecaster):
    """XGBoost-based forecaster for equipment availability prediction.

    Predicts future availability percentage based on:
    - Historical availability patterns
    - Maintenance event history
    - Calendar/seasonal effects
    - Upcoming TEEP events
    """

    def __init__(
        self,
        config: MaintenanceModelConfig | None = None,
        model_name: str = "maintenance_forecaster",
    ) -> None:
        super().__init__(model_name)
        self.config = config or MaintenanceModelConfig()
        self._quantile_models: dict[float, Any] = {}

    def train(
        self,
        X: pd.DataFrame,
        y: pd.Series,
        validation_split: float = 0.2,
    ) -> dict[str, float]:
        """Train the XGBoost model with time-series cross-validation."""
        import xgboost as xgb

        self.feature_columns = list(X.columns)
        self.target_column = y.name or "target"

        # Handle missing values
        X = X.fillna(X.median())
        y = y.fillna(y.median())

        # Remove any remaining NaN rows
        valid_mask = ~(X.isna().any(axis=1) | y.isna())
        X = X[valid_mask]
        y = y[valid_mask]

        # Time-series split for validation
        n_val = int(len(X) * validation_split)
        X_train, X_val = X.iloc[:-n_val], X.iloc[-n_val:]
        y_train, y_val = y.iloc[:-n_val], y.iloc[-n_val:]

        # Train main model
        self.model = xgb.XGBRegressor(
            n_estimators=self.config.n_estimators,
            max_depth=self.config.max_depth,
            learning_rate=self.config.learning_rate,
            min_child_weight=self.config.min_child_weight,
            subsample=self.config.subsample,
            colsample_bytree=self.config.colsample_bytree,
            random_state=42,
            n_jobs=-1,
        )

        self.model.fit(
            X_train,
            y_train,
            eval_set=[(X_val, y_val)],
            verbose=False,
        )

        # Train quantile models for confidence intervals
        for quantile in self.config.quantiles:
            q_model = xgb.XGBRegressor(
                n_estimators=self.config.n_estimators,
                max_depth=self.config.max_depth,
                learning_rate=self.config.learning_rate,
                objective="reg:quantileerror",
                quantile_alpha=quantile,
                random_state=42,
                n_jobs=-1,
            )
            q_model.fit(X_train, y_train, verbose=False)
            self._quantile_models[quantile] = q_model

        # Calculate validation metrics
        y_pred = self.model.predict(X_val)
        metrics = self._calculate_metrics(y_val.values, y_pred)

        # Cross-validation score
        tscv = TimeSeriesSplit(n_splits=self.config.cv_folds)
        cv_scores = cross_val_score(
            self.model, X, y, cv=tscv, scoring="neg_mean_absolute_error"
        )
        metrics["cv_mae"] = float(-cv_scores.mean())
        metrics["cv_mae_std"] = float(cv_scores.std())

        # Store metadata
        self.metadata = ModelMetadata(
            model_name=self.model_name,
            version="1.0.0",
            trained_at=datetime.now(),
            training_samples=len(X_train),
            feature_columns=self.feature_columns,
            target_column=self.target_column,
            metrics=metrics,
            hyperparameters={
                "n_estimators": self.config.n_estimators,
                "max_depth": self.config.max_depth,
                "learning_rate": self.config.learning_rate,
            },
        )

        self._is_trained = True
        return metrics

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """Generate point predictions for availability."""
        if not self._is_trained:
            raise RuntimeError("Model must be trained before prediction")

        X = X[self.feature_columns].fillna(0)
        predictions = self.model.predict(X)

        # Clip to valid availability range [0, 1]
        return np.clip(predictions, 0, 1)

    def predict_with_confidence(
        self, X: pd.DataFrame, confidence_level: float = 0.9
    ) -> list[ForecastResult]:
        """Generate predictions with confidence intervals using quantile regression."""
        if not self._is_trained:
            raise RuntimeError("Model must be trained before prediction")

        X = X[self.feature_columns].fillna(0)

        # Point predictions
        predictions = self.model.predict(X)

        # Quantile predictions for confidence intervals
        lower_quantile = (1 - confidence_level) / 2
        upper_quantile = 1 - lower_quantile

        if lower_quantile in self._quantile_models and upper_quantile in self._quantile_models:
            lower_bounds = self._quantile_models[lower_quantile].predict(X)
            upper_bounds = self._quantile_models[upper_quantile].predict(X)
        else:
            # Fallback: use residual-based intervals
            residual_std = 0.05  # Approximate
            z = 1.96 if confidence_level == 0.95 else 1.645
            lower_bounds = predictions - z * residual_std
            upper_bounds = predictions + z * residual_std

        # Get feature importance
        importance = self.get_feature_importance()

        results = []
        for i in range(len(predictions)):
            # Estimate confidence based on prediction stability
            pred_range = upper_bounds[i] - lower_bounds[i]
            confidence = max(0.5, 1 - pred_range)  # Narrower range = higher confidence

            results.append(
                ForecastResult(
                    prediction=float(np.clip(predictions[i], 0, 1)),
                    confidence=float(confidence),
                    lower_bound=float(np.clip(lower_bounds[i], 0, 1)),
                    upper_bound=float(np.clip(upper_bounds[i], 0, 1)),
                    feature_importance=importance,
                    metadata={"confidence_level": confidence_level},
                )
            )

        return results

    def get_shap_explanation(self, X: pd.DataFrame) -> dict[str, Any]:
        """Get SHAP-based feature explanations for predictions."""
        if not self._is_trained:
            raise RuntimeError("Model must be trained before explanation")

        try:
            import shap

            X = X[self.feature_columns].fillna(0)

            explainer = shap.TreeExplainer(self.model)
            shap_values = explainer.shap_values(X)

            # Aggregate explanations
            mean_abs_shap = np.abs(shap_values).mean(axis=0)
            feature_importance = dict(zip(self.feature_columns, mean_abs_shap))

            return {
                "shap_values": shap_values.tolist(),
                "feature_importance": feature_importance,
                "expected_value": float(explainer.expected_value),
            }
        except ImportError:
            return {"error": "SHAP not installed"}

    def predict_for_unit(
        self,
        unit_id: str,
        features_df: pd.DataFrame,
        horizon_days: int = 14,
    ) -> dict[str, Any]:
        """Generate forecast summary for a specific unit.

        Returns aggregated predictions across all platforms in the unit.
        """
        unit_data = features_df[features_df["unit_id"] == unit_id].copy()

        if len(unit_data) == 0:
            return {"error": f"No data found for unit {unit_id}"}

        # Get latest snapshot per platform
        latest = (
            unit_data.sort_values("snapshot_date")
            .groupby("platform_id")
            .last()
            .reset_index()
        )

        # Predict for each platform
        X = latest[self.feature_columns].fillna(0)
        results = self.predict_with_confidence(X)

        # Aggregate results
        predictions = [r.prediction for r in results]
        confidences = [r.confidence for r in results]

        return {
            "unit_id": unit_id,
            "horizon_days": horizon_days,
            "platform_count": len(predictions),
            "mean_availability": float(np.mean(predictions)),
            "min_availability": float(np.min(predictions)),
            "max_availability": float(np.max(predictions)),
            "mean_confidence": float(np.mean(confidences)),
            "at_risk_platforms": int(sum(1 for p in predictions if p < 0.8)),
            "predictions": [r.to_dict() for r in results],
        }
