"""Tests for ML models."""

import numpy as np
import pandas as pd
import pytest

from arcnet_ml.data.synthetic import SyntheticDataGenerator
from arcnet_ml.etl.transforms import FeatureTransformer
from arcnet_ml.models.maintenance import MaintenanceForecaster, MaintenanceModelConfig


class TestMaintenanceForecaster:
    """Tests for MaintenanceForecaster."""

    @pytest.fixture
    def sample_data(self) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
        """Generate sample data for testing."""
        generator = SyntheticDataGenerator()
        data = generator.generate_all()
        return data["readiness"], data["maintenance"], data["teep"]

    @pytest.fixture
    def feature_df(
        self, sample_data: tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]
    ) -> pd.DataFrame:
        """Prepare features from sample data."""
        readiness, maintenance, teep = sample_data
        transformer = FeatureTransformer()
        return transformer.prepare_maintenance_features(
            readiness_df=readiness,
            maintenance_df=maintenance,
            teep_df=teep,
        )

    def test_train_returns_metrics(self, feature_df: pd.DataFrame) -> None:
        """Training should return evaluation metrics."""
        transformer = FeatureTransformer()
        feature_cols = transformer.get_feature_columns(feature_df)

        train_df = feature_df.dropna(subset=["availability_pct_target"])
        if len(train_df) < 100:
            pytest.skip("Insufficient training data")

        X = train_df[feature_cols]
        y = train_df["availability_pct_target"]

        model = MaintenanceForecaster()
        metrics = model.train(X, y)

        assert "mae" in metrics
        assert "rmse" in metrics
        assert "r2" in metrics
        assert metrics["mae"] >= 0
        assert metrics["r2"] <= 1

    def test_predict_returns_array(self, feature_df: pd.DataFrame) -> None:
        """Prediction should return numpy array."""
        transformer = FeatureTransformer()
        feature_cols = transformer.get_feature_columns(feature_df)

        train_df = feature_df.dropna(subset=["availability_pct_target"])
        if len(train_df) < 100:
            pytest.skip("Insufficient training data")

        X = train_df[feature_cols]
        y = train_df["availability_pct_target"]

        model = MaintenanceForecaster()
        model.train(X, y)

        predictions = model.predict(X.head(10))

        assert isinstance(predictions, np.ndarray)
        assert len(predictions) == 10
        assert all(0 <= p <= 1 for p in predictions)

    def test_predict_with_confidence_returns_results(
        self, feature_df: pd.DataFrame
    ) -> None:
        """Prediction with confidence should return ForecastResult objects."""
        transformer = FeatureTransformer()
        feature_cols = transformer.get_feature_columns(feature_df)

        train_df = feature_df.dropna(subset=["availability_pct_target"])
        if len(train_df) < 100:
            pytest.skip("Insufficient training data")

        X = train_df[feature_cols]
        y = train_df["availability_pct_target"]

        model = MaintenanceForecaster()
        model.train(X, y)

        results = model.predict_with_confidence(X.head(5))

        assert len(results) == 5
        for result in results:
            assert 0 <= result.prediction <= 1
            assert 0 <= result.confidence <= 1
            assert result.lower_bound <= result.prediction <= result.upper_bound

    def test_untrained_model_raises_error(self, feature_df: pd.DataFrame) -> None:
        """Predicting with untrained model should raise error."""
        transformer = FeatureTransformer()
        feature_cols = transformer.get_feature_columns(feature_df)

        model = MaintenanceForecaster()

        with pytest.raises(RuntimeError, match="must be trained"):
            model.predict(feature_df[feature_cols].head(5))

    def test_feature_importance_after_training(
        self, feature_df: pd.DataFrame
    ) -> None:
        """Feature importance should be available after training."""
        transformer = FeatureTransformer()
        feature_cols = transformer.get_feature_columns(feature_df)

        train_df = feature_df.dropna(subset=["availability_pct_target"])
        if len(train_df) < 100:
            pytest.skip("Insufficient training data")

        X = train_df[feature_cols]
        y = train_df["availability_pct_target"]

        model = MaintenanceForecaster()
        model.train(X, y)

        importance = model.get_feature_importance()

        assert len(importance) == len(feature_cols)
        assert all(v >= 0 for v in importance.values())

    def test_save_and_load_model(
        self, feature_df: pd.DataFrame, tmp_path: pytest.TempPathFactory
    ) -> None:
        """Model should be saveable and loadable."""
        transformer = FeatureTransformer()
        feature_cols = transformer.get_feature_columns(feature_df)

        train_df = feature_df.dropna(subset=["availability_pct_target"])
        if len(train_df) < 100:
            pytest.skip("Insufficient training data")

        X = train_df[feature_cols]
        y = train_df["availability_pct_target"]

        # Train and save
        model = MaintenanceForecaster()
        model.train(X, y)
        original_predictions = model.predict(X.head(5))

        model_path = tmp_path / "model.joblib"
        model.save(model_path)

        # Load and verify
        loaded_model = MaintenanceForecaster()
        loaded_model.load(model_path)

        loaded_predictions = loaded_model.predict(X.head(5))

        np.testing.assert_array_almost_equal(original_predictions, loaded_predictions)
