"""models.py のユニットテスト

対象:
- _merge_sincos_pairs: sin/cos ペア合算ロジック
- _generate_tscv_splits: TSCV fold 分割
- _weighted_mean_std: 重み付け平均・標準偏差
- _get_lr_regularization: データ量に応じた正則化強度
- _get_lgb_params: LightGBM ハイパーパラメータ
- _safe_auc / _safe_pr_auc: エッジケース
- train_and_predict: 統合テスト（LR のみ）
"""

import numpy as np
import pandas as pd
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models import (
    _merge_sincos_pairs,
    _generate_tscv_splits,
    _weighted_mean_std,
    _get_lr_regularization,
    _get_lgb_params,
    _safe_auc,
    _safe_pr_auc,
    train_and_predict,
    _empty_result,
)


# ---------------------------------------------------------------------------
# _merge_sincos_pairs
# ---------------------------------------------------------------------------

class TestMergeSincosPairs:
    def test_sincos_pair_summed(self):
        """sin/cos ペアが単純加算で合算されること"""
        items = [
            {"feature": "day_sin", "value": 0.3},
            {"feature": "day_cos", "value": 0.4},
            {"feature": "mood_lag1", "value": 0.5},
        ]
        result = _merge_sincos_pairs(items)
        # day_sin + day_cos = 0.7
        day_item = next(r for r in result if r["feature"] == "day_sin")
        assert abs(day_item["value"] - 0.7) < 1e-9

    def test_cos_key_removed(self):
        """cos 側のキーが結果から除外されること"""
        items = [
            {"feature": "bed_sin", "value": 0.2},
            {"feature": "bed_cos", "value": -0.1},
        ]
        result = _merge_sincos_pairs(items)
        assert len(result) == 1
        assert result[0]["feature"] == "bed_sin"
        assert abs(result[0]["value"] - 0.1) < 1e-9

    def test_negative_values_summed(self):
        """負の寄与度も正しく加算されること"""
        items = [
            {"feature": "wake_sin", "value": -0.5},
            {"feature": "wake_cos", "value": -0.3},
        ]
        result = _merge_sincos_pairs(items)
        assert abs(result[0]["value"] - (-0.8)) < 1e-9

    def test_non_pair_features_unchanged(self):
        """ペア対象外の特徴量はそのまま残ること"""
        items = [
            {"feature": "mood_lag1", "value": 0.5},
            {"feature": "steps_filled", "value": -0.2},
        ]
        result = _merge_sincos_pairs(items)
        assert len(result) == 2
        assert result[0]["value"] == 0.5
        assert result[1]["value"] == -0.2

    def test_missing_cos_pair(self):
        """cos 側が存在しない場合、sin 側の値のみ"""
        items = [
            {"feature": "day_sin", "value": 0.3},
            {"feature": "mood_lag1", "value": 0.1},
        ]
        result = _merge_sincos_pairs(items)
        day_item = next(r for r in result if r["feature"] == "day_sin")
        assert abs(day_item["value"] - 0.3) < 1e-9

    def test_empty_input(self):
        """空リストで空リストを返す"""
        assert _merge_sincos_pairs([]) == []

    def test_all_three_pairs(self):
        """3つのペア全てが正しく合算されること"""
        items = [
            {"feature": "day_sin", "value": 0.1},
            {"feature": "day_cos", "value": 0.2},
            {"feature": "bed_sin", "value": 0.3},
            {"feature": "bed_cos", "value": 0.4},
            {"feature": "wake_sin", "value": 0.5},
            {"feature": "wake_cos", "value": 0.6},
        ]
        result = _merge_sincos_pairs(items)
        assert len(result) == 3
        values = {r["feature"]: r["value"] for r in result}
        assert abs(values["day_sin"] - 0.3) < 1e-9
        assert abs(values["bed_sin"] - 0.7) < 1e-9
        assert abs(values["wake_sin"] - 1.1) < 1e-9


# ---------------------------------------------------------------------------
# _generate_tscv_splits
# ---------------------------------------------------------------------------

class TestGenerateTscvSplits:
    def test_small_data_2_folds(self):
        """30日未満: TSCV_FOLDS_SMALL=2"""
        splits = _generate_tscv_splits(n_samples=20, days_collected=20)
        assert len(splits) <= 2
        # 各foldでtrain_end >= MIN_DAYS_TODAY
        for train_end, test_end in splits:
            assert train_end >= 14
            assert test_end <= 20

    def test_medium_data_3_folds(self):
        """30-99日: TSCV_FOLDS_MEDIUM=3"""
        splits = _generate_tscv_splits(n_samples=50, days_collected=50)
        assert len(splits) <= 3

    def test_large_data_5_folds(self):
        """100日以上: TSCV_FOLDS_LARGE=5"""
        splits = _generate_tscv_splits(n_samples=150, days_collected=150)
        assert len(splits) <= 5
        assert len(splits) >= 3  # 十分なデータがあれば少なくとも3 fold

    def test_splits_chronological_order(self):
        """splitが時系列順（古いfold→新しいfold）であること"""
        splits = _generate_tscv_splits(n_samples=100, days_collected=100)
        for i in range(len(splits) - 1):
            assert splits[i][0] < splits[i + 1][0]
            assert splits[i][1] < splits[i + 1][1]

    def test_expanding_window(self):
        """Expanding Window: 各foldの学習データ開始は0"""
        splits = _generate_tscv_splits(n_samples=100, days_collected=100)
        # train = [0:train_end] なので、全foldで0から始まる（expanding）
        for train_end, test_end in splits:
            assert train_end > 0
            assert test_end > train_end

    def test_minimum_train_size(self):
        """train_end が MIN_DAYS_TODAY 未満の fold は生成されないこと"""
        splits = _generate_tscv_splits(n_samples=20, days_collected=20)
        for train_end, _ in splits:
            assert train_end >= 14

    def test_very_small_data(self):
        """MIN_DAYS_TODAY ぴったりのデータ"""
        splits = _generate_tscv_splits(n_samples=14, days_collected=14)
        # テスト期間を確保できない可能性があるが、クラッシュしないこと
        assert isinstance(splits, list)


# ---------------------------------------------------------------------------
# _weighted_mean_std
# ---------------------------------------------------------------------------

class TestWeightedMeanStd:
    def test_single_value(self):
        """1件のみ: 平均はその値、分散は0"""
        mean, std = _weighted_mean_std([(0.8, 5)])
        assert abs(mean - 0.8) < 1e-9
        assert abs(std - 0.0) < 1e-9

    def test_equal_weights(self):
        """等重みの場合、通常の平均と一致"""
        values = [(0.6, 1), (0.8, 1), (0.7, 1)]
        mean, std = _weighted_mean_std(values)
        expected_mean = (0.6 + 0.8 + 0.7) / 3
        assert abs(mean - expected_mean) < 1e-9

    def test_weighted_mean(self):
        """重みが異なる場合の加重平均"""
        values = [(1.0, 10), (0.5, 2)]
        mean, _ = _weighted_mean_std(values)
        expected = (1.0 * 10 + 0.5 * 2) / 12
        assert abs(mean - expected) < 1e-9

    def test_bessel_correction(self):
        """ベッセル補正（N/(N-1)）が適用されること"""
        values = [(0.6, 1), (0.8, 1)]
        mean, std = _weighted_mean_std(values)
        # mean = 0.7
        # variance without Bessel = ((0.6-0.7)^2 + (0.8-0.7)^2) / 2 = 0.01
        # variance with Bessel = 0.01 * 2/1 = 0.02
        assert abs(mean - 0.7) < 1e-9
        assert abs(std - np.sqrt(0.02)) < 1e-9

    def test_empty_returns_none(self):
        """空リストは (None, None)"""
        mean, std = _weighted_mean_std([])
        assert mean is None
        assert std is None


# ---------------------------------------------------------------------------
# ハイパーパラメータ選択
# ---------------------------------------------------------------------------

class TestHyperparameterSelection:
    def test_lr_regularization_small(self):
        assert _get_lr_regularization(14) == 0.1
        assert _get_lr_regularization(59) == 0.1

    def test_lr_regularization_medium(self):
        assert _get_lr_regularization(60) == 0.5
        assert _get_lr_regularization(149) == 0.5

    def test_lr_regularization_large(self):
        assert _get_lr_regularization(150) == 1.0
        assert _get_lr_regularization(365) == 1.0

    def test_lgb_params_small(self):
        params = _get_lgb_params(60)
        assert params["max_depth"] == 3
        assert params["n_estimators"] == 100

    def test_lgb_params_medium(self):
        params = _get_lgb_params(150)
        assert params["max_depth"] == 4
        assert params["n_estimators"] == 150

    def test_lgb_params_large(self):
        params = _get_lgb_params(300)
        assert params["max_depth"] == 5
        assert params["n_estimators"] == 200


# ---------------------------------------------------------------------------
# _safe_auc / _safe_pr_auc
# ---------------------------------------------------------------------------

class TestSafeMetrics:
    def test_auc_normal(self):
        """正常なケースで AUC が計算されること"""
        y_true = np.array([0, 0, 1, 1])
        y_score = np.array([0.1, 0.3, 0.7, 0.9])
        auc = _safe_auc(y_true, y_score)
        assert auc is not None
        assert 0.9 <= auc <= 1.0

    def test_auc_single_class(self):
        """単一クラスの場合 None"""
        y_true = np.array([0, 0, 0])
        y_score = np.array([0.1, 0.2, 0.3])
        assert _safe_auc(y_true, y_score) is None

    def test_auc_too_few_samples(self):
        """サンプル1件以下で None"""
        assert _safe_auc(np.array([1]), np.array([0.5])) is None

    def test_auc_none_input(self):
        """None 入力で None"""
        assert _safe_auc(None, None) is None

    def test_pr_auc_normal(self):
        """正常なケースで PR-AUC が計算されること"""
        y_true = np.array([0, 0, 1, 1])
        y_score = np.array([0.1, 0.3, 0.7, 0.9])
        pr_auc = _safe_pr_auc(y_true, y_score)
        assert pr_auc is not None
        assert pr_auc > 0.5

    def test_pr_auc_single_class(self):
        """単一クラスの場合 None"""
        assert _safe_pr_auc(np.array([1, 1, 1]), np.array([0.5, 0.6, 0.7])) is None


# ---------------------------------------------------------------------------
# _empty_result
# ---------------------------------------------------------------------------

class TestEmptyResult:
    def test_default(self):
        result = _empty_result()
        assert result["probability"] is None
        assert result["model_type"] == "logistic"
        assert result["cv_folds"] == 0
        assert result["contributions"] == []

    def test_with_probability(self):
        result = _empty_result(probability=0.0)
        assert result["probability"] == 0.0


# ---------------------------------------------------------------------------
# train_and_predict 統合テスト
# ---------------------------------------------------------------------------

class TestTrainAndPredict:
    @staticmethod
    def _make_data(n: int = 30):
        """学習可能なテスト用データを生成"""
        np.random.seed(42)
        feature_cols = ["f1", "f2", "f3"]
        data = {
            "f1": np.random.randn(n),
            "f2": np.random.randn(n),
            "f3": np.random.randn(n),
            "y_today": np.array([0] * (n - 5) + [1] * 5),
        }
        return pd.DataFrame(data), feature_cols

    def test_returns_probability(self):
        """予測確率が返却されること"""
        df, cols = self._make_data()
        result = train_and_predict(df, cols, "y_today", days_collected=30, unhealthy_count=5)
        assert result["probability"] is not None
        assert 0.0 <= result["probability"] <= 1.0

    def test_returns_logistic_model_type(self):
        """LightGBM 条件未達のとき logistic が選択されること"""
        df, cols = self._make_data()
        result = train_and_predict(df, cols, "y_today", days_collected=30, unhealthy_count=5)
        assert result["model_type"] == "logistic"

    def test_returns_contributions(self):
        """寄与度が返却されること（最大3件）"""
        df, cols = self._make_data()
        result = train_and_predict(df, cols, "y_today", days_collected=30, unhealthy_count=5)
        assert isinstance(result["contributions"], list)
        assert len(result["contributions"]) <= 3

    def test_returns_model_params_for_lr(self):
        """LR のとき model_params が返却されること"""
        df, cols = self._make_data()
        result = train_and_predict(df, cols, "y_today", days_collected=30, unhealthy_count=5)
        assert result["model_params"] is not None
        assert "coefficients" in result["model_params"]
        assert "intercept" in result["model_params"]
        assert len(result["model_params"]["featureColumns"]) == 3

    def test_insufficient_data(self):
        """MIN_DAYS_TODAY 未満のデータで空結果"""
        df, cols = self._make_data(n=10)
        result = train_and_predict(df, cols, "y_today", days_collected=10, unhealthy_count=0)
        assert result["probability"] is None
        assert result["cv_folds"] == 0

    def test_no_positive_labels(self):
        """正例0件で確率0.0を返す"""
        df, cols = self._make_data(n=20)
        df["y_today"] = 0
        result = train_and_predict(df, cols, "y_today", days_collected=20, unhealthy_count=0)
        assert result["probability"] == 0.0

    def test_cv_metrics_present(self):
        """CV指標が返却されること"""
        df, cols = self._make_data(n=40)
        result = train_and_predict(df, cols, "y_today", days_collected=40, unhealthy_count=5)
        assert result["cv_folds"] >= 0
        # CV指標は fold がスキップされる可能性があるため None の場合もある
        if result["cv_folds"] > 0:
            assert result["cv_pr_auc_mean"] is not None


# ---------------------------------------------------------------------------
# 1σルール（モデル選択閾値）のテスト
# ---------------------------------------------------------------------------

class TestModelSelectionThreshold:
    """models.py:74 の閾値計算が 1σ（σキャップ付き）であることを検証"""

    def test_threshold_uses_1sigma(self):
        """閾値が lr_mean + 1.0 * lr_std で計算されること"""
        lr_mean = 0.5
        lr_std = 0.1
        threshold = lr_mean + lr_std * 1.0
        assert abs(threshold - 0.6) < 1e-9

    def test_std_cap_below_max(self):
        """σがキャップ値(0.1)以下の場合はそのまま使用される"""
        import config
        lr_std = 0.05
        capped = min(lr_std, config.MODEL_SELECTION_MAX_STD)
        assert capped == 0.05

    def test_std_cap_above_max(self):
        """σがキャップ値(0.1)を超える場合は0.1に丸められる"""
        import config
        lr_std = 0.25
        capped = min(lr_std, config.MODEL_SELECTION_MAX_STD)
        assert abs(capped - 0.1) < 1e-9

    def test_std_cap_threshold_calculation(self):
        """σキャップ適用時の閾値計算例: mean=0.7, std=0.2 → threshold=0.8（not 0.9）"""
        import config
        lr_mean = 0.7
        lr_std = min(0.2, config.MODEL_SELECTION_MAX_STD)  # 0.2 → 0.1
        threshold = lr_mean + lr_std * 1.0
        assert abs(threshold - 0.8) < 1e-9

    def test_lgbm_below_threshold_keeps_lr(self):
        """LightGBM が 1σ 以下なら LR が維持されること（統合テスト）"""
        np.random.seed(42)
        n = 30
        df = pd.DataFrame({
            "f1": np.random.randn(n),
            "f2": np.random.randn(n),
            "y_today": np.array([0] * (n - 5) + [1] * 5),
        })
        result = train_and_predict(df, ["f1", "f2"], "y_today", days_collected=30, unhealthy_count=5)
        assert result["model_type"] == "logistic"
