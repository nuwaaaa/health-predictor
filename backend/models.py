"""モデル学習・予測・比較

設計書 Section 10 に基づく。
- 初期: ロジスティック回帰（scikit-learn）
- 条件達成後: LightGBM と両方学習し、検証スコアで自動選択
- 検証: 直近14日をテスト、残りをトレーニング（時系列分割）
- 指標: AUC
"""

import logging

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
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
        }
    """
    # 学習可能な行のみ抽出
    valid = df.dropna(subset=[target_col] + feature_cols).copy()

    if len(valid) < config.MIN_DAYS_TODAY:
        return {"probability": None, "model_type": "logistic", "auc": None, "pr_auc": None}

    X = valid[feature_cols].values
    y = valid[target_col].values.astype(int)

    # 正例が0件の場合は予測不可（確率0を返す）
    if y.sum() == 0:
        return {"probability": 0.0, "model_type": "logistic", "auc": None, "pr_auc": None}

    # 最新行が予測対象（最終行）
    # 検証: 直近14日をテスト、残りをトレーニング
    n_test = min(config.VALIDATION_DAYS, len(valid) // 3)
    n_test = max(n_test, 1)

    X_train, X_test = X[:-n_test], X[-n_test:]
    y_train, y_test = y[:-n_test], y[-n_test:]

    # 学習データに正例がない場合
    if y_train.sum() == 0:
        # 全データで学習（検証スキップ）
        X_train, y_train = X, y
        X_test, y_test = None, None

    # スケーリング（ロジスティック回帰の収束改善）
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test) if X_test is not None else None
    X_last_scaled = scaler.transform(X[-1:])

    # --- ロジスティック回帰 ---
    # データ量に応じた正則化強度（要件書 Section 5）
    if days_collected < 60:
        lr_C = 0.1  # 強正則化
    elif days_collected < 150:
        lr_C = 0.5  # やや強
    else:
        lr_C = 1.0  # 標準

    lr_model = LogisticRegression(C=lr_C, max_iter=1000, random_state=42)
    lr_model.fit(X_train_scaled, y_train)
    lr_prob = float(lr_model.predict_proba(X_last_scaled)[:, 1][0])
    lr_test_proba = lr_model.predict_proba(X_test_scaled)[:, 1] if X_test_scaled is not None else None
    lr_auc = _safe_auc(y_test, lr_test_proba)
    lr_pr_auc = _safe_pr_auc(y_test, lr_test_proba)

    # 特徴量寄与度（標準化済み係数 × 特徴量値）
    lr_contributions = _calc_lr_contributions(lr_model, scaler, X[-1:], feature_cols)

    best_model_type = "logistic"
    best_prob = lr_prob
    best_auc = lr_auc
    best_pr_auc = lr_pr_auc

    # --- LightGBM（条件達成時のみ）---
    if (
        days_collected >= config.LGBM_MIN_DAYS
        and unhealthy_count >= config.LGBM_MIN_UNHEALTHY
    ):
        try:
            import lightgbm as lgb

            # データ量に応じたハイパーパラメータ（要件書 Section 5）
            if days_collected < 150:
                lgb_max_depth = 3
                lgb_num_leaves = 8
            else:
                lgb_max_depth = 5
                lgb_num_leaves = 31

            lgb_model = lgb.LGBMClassifier(
                n_estimators=100,
                max_depth=lgb_max_depth,
                learning_rate=0.1,
                num_leaves=lgb_num_leaves,
                min_child_samples=5,
                random_state=42,
                verbose=-1,
            )
            lgb_model.fit(X_train, y_train)
            lgb_prob = float(lgb_model.predict_proba(X[-1:])[:, 1][0])
            lgb_test_proba = lgb_model.predict_proba(X_test)[:, 1] if X_test is not None else None
            lgb_auc = _safe_auc(y_test, lgb_test_proba)
            lgb_pr_auc = _safe_pr_auc(y_test, lgb_test_proba)

            # AUCで比較して良い方を採用
            if lgb_auc is not None and lr_auc is not None:
                if lgb_auc > lr_auc:
                    best_model_type = "lightgbm"
                    best_prob = lgb_prob
                    best_auc = lgb_auc
                    best_pr_auc = lgb_pr_auc
                    logger.info(
                        "LightGBM selected (AUC: %.3f, PR-AUC: %s > LR AUC: %.3f, PR-AUC: %s)",
                        lgb_auc,
                        f"{lgb_pr_auc:.3f}" if lgb_pr_auc else "N/A",
                        lr_auc,
                        f"{lr_pr_auc:.3f}" if lr_pr_auc else "N/A",
                    )
                else:
                    logger.info(
                        "Logistic selected (AUC: %.3f, PR-AUC: %s >= LGBM AUC: %.3f, PR-AUC: %s)",
                        lr_auc,
                        f"{lr_pr_auc:.3f}" if lr_pr_auc else "N/A",
                        lgb_auc,
                        f"{lgb_pr_auc:.3f}" if lgb_pr_auc else "N/A",
                    )
            elif lgb_auc is not None:
                best_model_type = "lightgbm"
                best_prob = lgb_prob
                best_auc = lgb_auc
                best_pr_auc = lgb_pr_auc

            # LightGBMが採用された場合、SHAP寄与度を計算
            if best_model_type == "lightgbm":
                lr_contributions = _calc_lgb_contributions(lgb_model, X[-1:], feature_cols)

        except Exception as e:
            logger.warning("LightGBM training failed: %s", e)

    return {
        "probability": best_prob,
        "model_type": best_model_type,
        "auc": best_auc,
        "pr_auc": best_pr_auc,
        "contributions": lr_contributions,
    }


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
        items.sort(key=lambda x: abs(x["value"]), reverse=True)
        return items[:3]
    except Exception:
        return []
