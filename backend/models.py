"""モデル学習・予測・比較

設計書 Section 10 に基づく。
- 初期: ロジスティック回帰（scikit-learn）
- 条件達成後: LightGBM と両方学習し、検証スコアで自動選択
- 検証: Expanding Window TSCV（fold数はデータ量に応じて可変）
- 指標: PR-AUC（モデル選択）、ROC-AUC（ログ出力）
"""

import logging

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss, roc_auc_score
from sklearn.preprocessing import StandardScaler

import config

logger = logging.getLogger(__name__)


def train_and_predict(
    df: pd.DataFrame,
    feature_cols: list[str],
    target_col: str,
    days_collected: int,
    unhealthy_count: int,
) -> dict:
    """モデル学習 → 予測 → 結果返却

    返却:
        {
            "probability": float or None,
            "model_type": "logistic" or "lightgbm",
            "auc": float or None,
            "pr_auc": float or None,
            "cv_pr_auc_mean": float or None,
            "cv_pr_auc_std": float or None,
            "cv_folds": int,
            "contributions": list[dict],
            "model_params": dict or None,
        }
    """
    # 学習可能な行のみ抽出
    valid = df.dropna(subset=[target_col] + feature_cols).copy()

    if len(valid) < config.MIN_DAYS_TODAY:
        return _empty_result()

    X = valid[feature_cols].values
    y = valid[target_col].values.astype(int)

    # 正例が0件の場合は予測不可（確率0を返す）
    if y.sum() == 0:
        return _empty_result(probability=0.0)

    # --- TSCV でモデル評価 ---
    lr_cv = _tscv_evaluate_lr(X, y, days_collected)
    lgb_cv = None

    if (
        days_collected >= config.LGBM_MIN_DAYS
        and unhealthy_count >= config.LGBM_MIN_UNHEALTHY
    ):
        lgb_cv = _tscv_evaluate_lgb(X, y, days_collected)

    # --- モデル選択（1σルール: LightGBMがLRの平均+1σを超えた場合のみ切替）---
    # σが大きすぎるとLGBMに不利になるため、上限をキャップする
    best_model_type = "logistic"
    if lgb_cv is not None and lgb_cv["pr_auc_mean"] is not None:
        lr_mean = lr_cv["pr_auc_mean"]
        lr_std = min(lr_cv["pr_auc_std"] or 0.0, config.MODEL_SELECTION_MAX_STD)
        lgb_mean = lgb_cv["pr_auc_mean"]
        threshold = (lr_mean or 0.0) + lr_std * 1.0

        if lr_mean is None or lgb_mean > threshold:
            best_model_type = "lightgbm"
            logger.info(
                "LightGBM selected (CV PR-AUC: %.3f±%.3f, %d folds > LR: %s + 1σ=%.3f, %d folds)",
                lgb_mean,
                lgb_cv["pr_auc_std"] or 0.0,
                lgb_cv["valid_folds"],
                f"{lr_mean:.3f}±{lr_std:.3f}" if lr_mean is not None else "N/A",
                threshold,
                lr_cv["valid_folds"],
            )
        else:
            logger.info(
                "Logistic retained — 1σ rule (LR: %s, threshold: %.3f, LGBM: %.3f±%.3f)",
                f"{lr_mean:.3f}±{lr_std:.3f}" if lr_mean is not None else "N/A",
                threshold,
                lgb_mean,
                lgb_cv["pr_auc_std"] or 0.0,
            )

    # --- 選択されたモデルで全データ学習 → 最終予測 ---
    selected_cv = lgb_cv if best_model_type == "lightgbm" else lr_cv

    if best_model_type == "logistic":
        prob, contributions, model_params = _final_train_lr(X, y, days_collected, feature_cols)
    else:
        prob, contributions, model_params = _final_train_lgb(X, y, days_collected, feature_cols)

    return {
        "probability": prob,
        "model_type": best_model_type,
        "auc": selected_cv["auc_mean"],
        "pr_auc": selected_cv["pr_auc_mean"],
        "brier_score": selected_cv["brier_score"],
        "cv_pr_auc_mean": selected_cv["pr_auc_mean"],
        "cv_pr_auc_std": selected_cv["pr_auc_std"],
        "cv_folds": selected_cv["valid_folds"],
        "contributions": contributions,
        "model_params": model_params,
    }


def _empty_result(probability=None) -> dict:
    return {
        "probability": probability,
        "model_type": "logistic",
        "auc": None,
        "pr_auc": None,
        "brier_score": None,
        "cv_pr_auc_mean": None,
        "cv_pr_auc_std": None,
        "cv_folds": 0,
        "contributions": [],
        "model_params": None,
    }


# ---------------------------------------------------------------------------
# TSCV (Expanding Window)
# ---------------------------------------------------------------------------

def _generate_tscv_splits(n_samples: int, days_collected: int) -> list[tuple[int, int]]:
    """Expanding Window TSCVのfold境界を生成する。

    返却: [(train_end, test_end), ...] のリスト
    train=[0:train_end], test=[train_end:test_end]
    """
    if days_collected < 30:
        n_folds = config.TSCV_FOLDS_SMALL
    elif days_collected < 100:
        n_folds = config.TSCV_FOLDS_MEDIUM
    else:
        n_folds = config.TSCV_FOLDS_LARGE

    # テストサイズをデータ量に比例させる
    n_test = max(config.TSCV_MIN_TEST_SIZE, n_samples // (n_folds + 1))

    # テスト期間がデータの1/3を超えないように調整
    n_test = min(n_test, n_samples // 3)
    n_test = max(n_test, 1)

    splits = []
    for i in range(n_folds):
        test_end = n_samples - i * n_test
        train_end = test_end - n_test
        if train_end < config.MIN_DAYS_TODAY:
            break
        splits.append((train_end, test_end))

    # 時系列順に並べ替え（古いfoldから）
    splits.reverse()
    return splits


def _tscv_evaluate_lr(
    X: np.ndarray, y: np.ndarray, days_collected: int,
) -> dict:
    """ロジスティック回帰のTSCV評価"""
    splits = _generate_tscv_splits(len(X), days_collected)
    pr_aucs_w: list[tuple[float, int]] = []  # (pr_auc, n_pos)
    roc_aucs_w: list[tuple[float, int]] = []
    briers_w: list[tuple[float, int]] = []

    lr_C = _get_lr_regularization(days_collected)
    skipped = 0

    for train_end, test_end in splits:
        X_train, y_train = X[:train_end], y[:train_end]
        X_test, y_test = X[train_end:test_end], y[train_end:test_end]

        n_pos = int(y_test.sum())

        # trainに正例0 or テスト正例が最小閾値未満 → スキップ
        if y_train.sum() == 0 or n_pos < config.TSCV_MIN_TEST_POSITIVES or len(np.unique(y_test)) < 2:
            skipped += 1
            continue

        scaler = StandardScaler()
        X_train_s = scaler.fit_transform(X_train)
        X_test_s = scaler.transform(X_test)

        model = LogisticRegression(C=lr_C, max_iter=1000, random_state=42, class_weight="balanced")
        model.fit(X_train_s, y_train)
        y_score = model.predict_proba(X_test_s)[:, 1]

        pr_auc = _safe_pr_auc(y_test, y_score)
        roc_auc = _safe_auc(y_test, y_score)
        if pr_auc is not None:
            pr_aucs_w.append((pr_auc, n_pos))
        if roc_auc is not None:
            roc_aucs_w.append((roc_auc, n_pos))
        briers_w.append((brier_score_loss(y_test, y_score), n_pos))

    if skipped:
        logger.info("LR TSCV: %d/%d folds skipped (test positives < %d)",
                     skipped, len(splits), config.TSCV_MIN_TEST_POSITIVES)

    return _aggregate_cv_results(pr_aucs_w, roc_aucs_w, briers_w, len(splits))


def _tscv_evaluate_lgb(
    X: np.ndarray, y: np.ndarray, days_collected: int,
) -> dict | None:
    """LightGBMのTSCV評価"""
    try:
        import lightgbm as lgb
    except Exception:
        return None

    splits = _generate_tscv_splits(len(X), days_collected)
    pr_aucs_w: list[tuple[float, int]] = []
    roc_aucs_w: list[tuple[float, int]] = []
    briers_w: list[tuple[float, int]] = []

    lgb_params = _get_lgb_params(days_collected)
    skipped = 0

    for train_end, test_end in splits:
        X_train, y_train = X[:train_end], y[:train_end]
        X_test, y_test = X[train_end:test_end], y[train_end:test_end]

        n_pos = int(y_test.sum())

        if y_train.sum() == 0 or n_pos < config.TSCV_MIN_TEST_POSITIVES or len(np.unique(y_test)) < 2:
            skipped += 1
            continue

        try:
            model = lgb.LGBMClassifier(**lgb_params, is_unbalance=True, random_state=42, verbose=-1)
            model.fit(X_train, y_train)
            y_score = model.predict_proba(X_test)[:, 1]

            pr_auc = _safe_pr_auc(y_test, y_score)
            roc_auc = _safe_auc(y_test, y_score)
            if pr_auc is not None:
                pr_aucs_w.append((pr_auc, n_pos))
            if roc_auc is not None:
                roc_aucs_w.append((roc_auc, n_pos))
            briers_w.append((brier_score_loss(y_test, y_score), n_pos))
        except Exception as e:
            logger.warning("LightGBM fold failed: %s", e)

    if skipped:
        logger.info("LGBM TSCV: %d/%d folds skipped (test positives < %d)",
                     skipped, len(splits), config.TSCV_MIN_TEST_POSITIVES)

    return _aggregate_cv_results(pr_aucs_w, roc_aucs_w, briers_w, len(splits))


def _aggregate_cv_results(
    pr_aucs_w: list[tuple[float, int]],
    roc_aucs_w: list[tuple[float, int]],
    briers_w: list[tuple[float, int]],
    total_folds: int,
) -> dict:
    """CV結果をテスト正例数で重み付け平均して集約する。"""
    pr_mean, pr_std = _weighted_mean_std(pr_aucs_w)
    auc_mean, auc_std = _weighted_mean_std(roc_aucs_w)
    brier_mean, _ = _weighted_mean_std(briers_w)
    return {
        "pr_auc_mean": pr_mean,
        "pr_auc_std": pr_std,
        "auc_mean": auc_mean,
        "auc_std": auc_std,
        "brier_score": brier_mean,
        "valid_folds": len(pr_aucs_w),
        "total_folds": total_folds,
    }


def _weighted_mean_std(
    values_weights: list[tuple[float, int]],
) -> tuple[float | None, float | None]:
    """(value, weight) のリストから重み付け平均と重み付き標準偏差を返す。

    ベッセル補正（N/(N-1)相当）を適用し、fold数が少ない場合の
    標準偏差過小評価を防止する。
    """
    if not values_weights:
        return None, None
    values = np.array([v for v, _ in values_weights])
    weights = np.array([w for _, w in values_weights], dtype=float)
    mean = float(np.average(values, weights=weights))
    variance = float(np.average((values - mean) ** 2, weights=weights))
    # ベッセル補正: N/(N-1) に相当する重み付き版
    n = len(values)
    if n > 1:
        variance *= n / (n - 1)
    std = float(np.sqrt(variance))
    return mean, std


# ---------------------------------------------------------------------------
# 最終学習（全データで学習 → 最終行を予測）
# ---------------------------------------------------------------------------

def _final_train_lr(
    X: np.ndarray, y: np.ndarray, days_collected: int, feature_cols: list[str],
) -> tuple[float, list[dict], dict]:
    """最終行を除いたデータでLR学習 → 最終行の予測確率・寄与度・モデルパラメータを返却"""
    lr_C = _get_lr_regularization(days_collected)
    scaler = StandardScaler()
    # 最終行（予測対象）を学習・スケーラーfitから除外してリーケージを防止
    X_train = X[:-1]
    y_train = y[:-1]
    X_train_scaled = scaler.fit_transform(X_train)
    X_last_scaled = scaler.transform(X[-1:])

    model = LogisticRegression(
        C=lr_C, max_iter=1000, random_state=42, class_weight="balanced",
    )
    model.fit(X_train_scaled, y_train)
    prob = float(model.predict_proba(X_last_scaled)[:, 1][0])
    contributions = _calc_lr_contributions(model, scaler, X[-1:], feature_cols)
    model_params = {
        "coefficients": model.coef_[0].tolist(),
        "intercept": float(model.intercept_[0]),
        "scalerMean": scaler.mean_.tolist(),
        "scalerScale": scaler.scale_.tolist(),
        "featureColumns": list(feature_cols),
    }
    return prob, contributions, model_params


def _final_train_lgb(
    X: np.ndarray, y: np.ndarray, days_collected: int, feature_cols: list[str],
) -> tuple[float, list[dict], None]:
    """最終行を除いたデータでLightGBM学習 → 最終行の予測確率・寄与度を返却"""
    import lightgbm as lgb

    lgb_params = _get_lgb_params(days_collected)
    # 最終行（予測対象）を学習から除外してリーケージを防止
    X_train = X[:-1]
    y_train = y[:-1]
    model = lgb.LGBMClassifier(**lgb_params, is_unbalance=True, random_state=42, verbose=-1)
    model.fit(X_train, y_train)
    prob = float(model.predict_proba(X[-1:])[:, 1][0])
    contributions = _calc_lgb_contributions(model, X[-1:], feature_cols)
    return prob, contributions, None


# ---------------------------------------------------------------------------
# ハイパーパラメータ
# ---------------------------------------------------------------------------

def _get_lr_regularization(days_collected: int) -> float:
    if days_collected < 60:
        return 0.1
    elif days_collected < 150:
        return 0.5
    else:
        return 1.0


def _get_lgb_params(days_collected: int) -> dict:
    if days_collected < 150:
        return dict(max_depth=3, num_leaves=8, n_estimators=100, min_child_samples=5, learning_rate=0.1)
    elif days_collected < 300:
        return dict(max_depth=4, num_leaves=16, n_estimators=150, min_child_samples=5, learning_rate=0.05)
    else:
        return dict(max_depth=5, num_leaves=31, n_estimators=200, min_child_samples=3, learning_rate=0.05)


# ---------------------------------------------------------------------------
# メトリクス
# ---------------------------------------------------------------------------

def _safe_auc(y_true, y_score) -> float | None:
    """ROC-AUCを安全に計算する。正例/負例のどちらかが0件の場合はNoneを返す。"""
    if y_true is None or y_score is None or len(y_true) < 2:
        return None
    if len(np.unique(y_true)) < 2:
        return None
    try:
        return float(roc_auc_score(y_true, y_score))
    except ValueError:
        return None


def _safe_pr_auc(y_true, y_score) -> float | None:
    """PR-AUC (Average Precision) を安全に計算する。"""
    if y_true is None or y_score is None or len(y_true) < 2:
        return None
    if len(np.unique(y_true)) < 2:
        return None
    try:
        return float(average_precision_score(y_true, y_score))
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# 寄与度計算
# ---------------------------------------------------------------------------

# sin/cos ペア定義: 合算して1つの寄与度として扱う
_SINCOS_PAIRS = {
    "day_sin": ("day_cos", "曜日"),
    "day_sin2": ("day_cos2", "曜日(2次)"),
    "bed_sin": ("bed_cos", "就寝時刻"),
    "wake_sin": ("wake_cos", "起床時刻"),
}
# cos 側のキー（sin 側で合算済みなのでスキップ用）
_SINCOS_COS_KEYS = {v[0] for v in _SINCOS_PAIRS.values()}


def _merge_sincos_pairs(items: list[dict]) -> list[dict]:
    """sin/cos ペアの寄与度を単純加算で合算する。

    LR の coef×feature も SHAP 値も log-odds 空間で加法的なので、
    sin/cos ペアの合算は単純和が正しい。
    ペアの feature 名は sin 側を代表として使用する。
    """
    value_map = {item["feature"]: item["value"] for item in items}
    merged = []
    seen = set()
    for item in items:
        feat = item["feature"]
        if feat in seen or feat in _SINCOS_COS_KEYS:
            continue
        seen.add(feat)
        if feat in _SINCOS_PAIRS:
            cos_key, _ = _SINCOS_PAIRS[feat]
            v_sin = item["value"]
            v_cos = value_map.get(cos_key, 0.0)
            merged.append({"feature": feat, "value": v_sin + v_cos})
        else:
            merged.append(item)
    return merged


def _calc_lr_contributions(
    model: LogisticRegression,
    scaler: StandardScaler,
    X_raw: np.ndarray,
    feature_cols: list[str],
) -> list[dict]:
    """ロジスティック回帰の寄与度: 標準化済み係数 × 標準化済み特徴量値。TOP3を返す。"""
    try:
        X_scaled = scaler.transform(X_raw)
        coefs = model.coef_[0]
        contributions = coefs * X_scaled[0]
        items = [
            {"feature": feature_cols[i], "value": float(contributions[i])}
            for i in range(len(feature_cols))
        ]
        items = _merge_sincos_pairs(items)
        items.sort(key=lambda x: abs(x["value"]), reverse=True)
        return items[:3]
    except Exception:
        return []


def _calc_lgb_contributions(
    model,
    X_raw: np.ndarray,
    feature_cols: list[str],
) -> list[dict]:
    """LightGBMの寄与度: SHAP値。TOP3を返す。"""
    try:
        import shap
        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(X_raw)
        # 二値分類の場合、正例クラスのSHAP値を使用
        if isinstance(shap_values, list):
            vals = shap_values[1][0]
        else:
            vals = shap_values[0]
        items = [
            {"feature": feature_cols[i], "value": float(vals[i])}
            for i in range(len(feature_cols))
        ]
        items = _merge_sincos_pairs(items)
        items.sort(key=lambda x: abs(x["value"]), reverse=True)
        return items[:3]
    except Exception:
        return []
