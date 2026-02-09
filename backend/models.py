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
from sklearn.metrics import roc_auc_score
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
        }
    """
    # 学習可能な行のみ抽出
    valid = df.dropna(subset=[target_col] + feature_cols).copy()

    if len(valid) < config.MIN_DAYS_TODAY:
        return {"probability": None, "model_type": "logistic", "auc": None}

    X = valid[feature_cols].values
    y = valid[target_col].values.astype(int)

    # 正例が0件の場合は予測不可（確率0を返す）
    if y.sum() == 0:
        return {"probability": 0.0, "model_type": "logistic", "auc": None}

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
    lr_model = LogisticRegression(max_iter=1000, random_state=42)
    lr_model.fit(X_train_scaled, y_train)
    lr_prob = float(lr_model.predict_proba(X_last_scaled)[:, 1][0])
    lr_auc = _safe_auc(y_test, lr_model.predict_proba(X_test_scaled)[:, 1]) if X_test_scaled is not None else None

    best_model_type = "logistic"
    best_prob = lr_prob
    best_auc = lr_auc

    # --- LightGBM（条件達成時のみ）---
    if (
        days_collected >= config.LGBM_MIN_DAYS
        and unhealthy_count >= config.LGBM_MIN_UNHEALTHY
    ):
        try:
            import lightgbm as lgb

            lgb_model = lgb.LGBMClassifier(
                n_estimators=100,
                max_depth=4,
                learning_rate=0.1,
                num_leaves=15,
                min_child_samples=5,
                random_state=42,
                verbose=-1,
            )
            lgb_model.fit(X_train, y_train)
            lgb_prob = float(lgb_model.predict_proba(X[-1:])[:, 1][0])
            lgb_auc = _safe_auc(y_test, lgb_model.predict_proba(X_test)[:, 1]) if X_test is not None else None

            # AUCで比較して良い方を採用
            if lgb_auc is not None and lr_auc is not None:
                if lgb_auc > lr_auc:
                    best_model_type = "lightgbm"
                    best_prob = lgb_prob
                    best_auc = lgb_auc
                    logger.info(
                        "LightGBM selected (AUC: %.3f > LR: %.3f)",
                        lgb_auc,
                        lr_auc,
                    )
                else:
                    logger.info(
                        "Logistic selected (AUC: %.3f >= LGBM: %.3f)",
                        lr_auc,
                        lgb_auc,
                    )
            elif lgb_auc is not None:
                # LRのAUCが計算できなかった場合はLGBMを採用
                best_model_type = "lightgbm"
                best_prob = lgb_prob
                best_auc = lgb_auc

        except Exception as e:
            logger.warning("LightGBM training failed: %s", e)

    return {
        "probability": best_prob,
        "model_type": best_model_type,
        "auc": best_auc,
    }


def _safe_auc(y_true, y_score) -> float | None:
    """AUCを安全に計算する。正例/負例のどちらかが0件の場合はNoneを返す。"""
    if y_true is None or len(y_true) < 2:
        return None
    if len(np.unique(y_true)) < 2:
        return None
    try:
        return float(roc_auc_score(y_true, y_score))
    except ValueError:
        return None
