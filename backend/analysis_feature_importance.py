"""特徴量重要度の分析スクリプト

周期エンコーディング特徴量（曜日・就寝時刻・起床時刻）が
他の特徴量と比較してどの程度支配的かを評価する。

使い方: python backend/analysis_feature_importance.py
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

from features import build_features, get_feature_columns
from labels import generate_labels


def generate_synthetic_data(n_days: int = 180, seed: int = 42) -> pd.DataFrame:
    """リアルなパターンを持つ合成データを生成する。

    - 月曜に不調になりやすい（曜日効果）
    - 深夜1時以降就寝で不調リスク上昇（就寝時刻効果）
    - 睡眠不足で不調リスク上昇
    - ストレス高で不調リスク上昇
    """
    rng = np.random.default_rng(seed)
    base_date = pd.Timestamp("2025-07-01")
    dates = [base_date + pd.Timedelta(days=i) for i in range(n_days)]

    rows = []
    prev_mood = 3.0
    for i, dt in enumerate(dates):
        dow = dt.dayofweek  # 0=Mon

        # 就寝時刻: 22:00-01:30 の範囲でランダム（週末は遅め）
        bed_base = 23.0 if dow < 5 else 24.5
        bed_hour = bed_base + rng.normal(0, 0.7)
        bed_hour = np.clip(bed_hour, 21.5, 26.0)  # 21:30 ~ 02:00
        bed_h = int(bed_hour) % 24
        bed_m = int((bed_hour % 1) * 60)
        bed_time = f"{bed_h:02d}:{bed_m:02d}"

        # 起床時刻: 6:30-8:00
        wake_hour = 7.0 + rng.normal(0, 0.3)
        wake_hour = np.clip(wake_hour, 6.0, 9.0)
        wake_h = int(wake_hour)
        wake_m = int((wake_hour % 1) * 60)
        wake_time = f"{wake_h:02d}:{wake_m:02d}"

        # 睡眠時間
        sleep_hours = (wake_hour + 24 - bed_hour) % 24
        sleep_hours = np.clip(sleep_hours, 4, 12)

        # 歩数
        steps = int(rng.normal(7000, 2000))
        steps = max(1000, steps)

        # ストレス (1-5)
        stress = int(np.clip(rng.normal(3, 1), 1, 5))

        # 不調確率の生成（各要因の影響度を設定）
        p_unhealthy = 0.15  # ベース確率

        # 曜日効果: 月曜 +15%, 金曜 -5%
        if dow == 0:
            p_unhealthy += 0.15
        elif dow == 4:
            p_unhealthy -= 0.05

        # 就寝時刻効果: 1時以降 +10%
        if bed_hour >= 25.0:
            p_unhealthy += 0.10
        elif bed_hour <= 23.0:
            p_unhealthy -= 0.05

        # 睡眠時間効果: 6h未満 +20%, 7-8h -5%
        if sleep_hours < 6:
            p_unhealthy += 0.20
        elif 7 <= sleep_hours <= 8:
            p_unhealthy -= 0.05

        # ストレス効果: 4以上 +15%
        if stress >= 4:
            p_unhealthy += 0.15
        elif stress <= 2:
            p_unhealthy -= 0.05

        # 前日の体調の影響: 不調連鎖
        if prev_mood <= 2:
            p_unhealthy += 0.10

        p_unhealthy = np.clip(p_unhealthy, 0.05, 0.80)
        mood = 2 if rng.random() < p_unhealthy else rng.choice([3, 4, 5], p=[0.4, 0.4, 0.2])
        prev_mood = mood

        rows.append({
            "date_key": dt.strftime("%Y-%m-%d"),
            "moodScore": float(mood),
            "sleep_hours": round(sleep_hours, 1),
            "bed_time": bed_time,
            "wake_time": wake_time,
            "steps": steps,
            "stress": stress,
        })

    return pd.DataFrame(rows)


def analyze_lr_importance(df: pd.DataFrame) -> pd.DataFrame:
    """LR の標準化係数の絶対値で特徴量重要度を評価する。"""
    feat_df = build_features(df)
    label_df = generate_labels(df)
    merged = feat_df.merge(label_df[["date_key", "y_3d"]], on="date_key")

    feature_cols = get_feature_columns()
    valid = merged.dropna(subset=["y_3d"] + feature_cols)
    X = valid[feature_cols].values
    y = valid["y_3d"].values.astype(int)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    model = LogisticRegression(C=0.5, max_iter=1000, random_state=42, class_weight="balanced")
    model.fit(X_scaled, y)

    coefs = model.coef_[0]
    importance = pd.DataFrame({
        "feature": feature_cols,
        "coef_std": coefs,
        "abs_coef": np.abs(coefs),
    }).sort_values("abs_coef", ascending=False)

    return importance


def analyze_lr_importance_merged(df: pd.DataFrame) -> pd.DataFrame:
    """sin/cosペアを合算した後の重要度（全データ平均）。"""
    feat_df = build_features(df)
    label_df = generate_labels(df)
    merged = feat_df.merge(label_df[["date_key", "y_3d"]], on="date_key")

    feature_cols = get_feature_columns()
    valid = merged.dropna(subset=["y_3d"] + feature_cols)
    X = valid[feature_cols].values
    y = valid["y_3d"].values.astype(int)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    model = LogisticRegression(C=0.5, max_iter=1000, random_state=42, class_weight="balanced")
    model.fit(X_scaled, y)

    coefs = model.coef_[0]

    # 各サンプルの寄与度を計算して平均
    contributions = coefs * X_scaled  # (n_samples, n_features)

    # sin/cos ペア定義
    sincos_pairs = {
        "day_sin": ("day_cos", "曜日"),
        "bed_sin": ("bed_cos", "就寝時刻"),
        "wake_sin": ("wake_cos", "起床時刻"),
    }
    cos_keys = {v[0] for v in sincos_pairs.values()}
    feat_idx = {f: i for i, f in enumerate(feature_cols)}

    rows = []
    for i, feat in enumerate(feature_cols):
        if feat in cos_keys:
            continue
        if feat in sincos_pairs:
            cos_key, label = sincos_pairs[feat]
            j = feat_idx[cos_key]
            merged_contrib = contributions[:, i] + contributions[:, j]
            rows.append({
                "feature": label,
                "mean_abs_contrib": float(np.mean(np.abs(merged_contrib))),
                "mean_contrib": float(np.mean(merged_contrib)),
                "std_contrib": float(np.std(merged_contrib)),
            })
        else:
            rows.append({
                "feature": feat,
                "mean_abs_contrib": float(np.mean(np.abs(contributions[:, i]))),
                "mean_contrib": float(np.mean(contributions[:, i])),
                "std_contrib": float(np.std(contributions[:, i])),
            })

    result = pd.DataFrame(rows).sort_values("mean_abs_contrib", ascending=False)
    return result


def analyze_lgb_importance(df: pd.DataFrame) -> pd.DataFrame | None:
    """LightGBM の SHAP ベース重要度（sin/cosペア合算後）。"""
    try:
        import lightgbm as lgb
        import shap
    except ImportError:
        print("lightgbm or shap not installed, skipping LGB analysis")
        return None

    feat_df = build_features(df)
    label_df = generate_labels(df)
    merged = feat_df.merge(label_df[["date_key", "y_3d"]], on="date_key")

    feature_cols = get_feature_columns()
    valid = merged.dropna(subset=["y_3d"] + feature_cols)
    X = valid[feature_cols].values
    y = valid["y_3d"].values.astype(int)

    model = lgb.LGBMClassifier(
        max_depth=4, num_leaves=16, n_estimators=150,
        min_child_samples=5, learning_rate=0.05,
        is_unbalance=True, random_state=42, verbose=-1,
    )
    model.fit(X, y)

    explainer = shap.TreeExplainer(model)
    shap_values = explainer.shap_values(X)
    if isinstance(shap_values, list):
        vals = shap_values[1]  # 正例クラス
    else:
        vals = shap_values

    # sin/cos ペア合算
    sincos_pairs = {
        "day_sin": ("day_cos", "曜日"),
        "bed_sin": ("bed_cos", "就寝時刻"),
        "wake_sin": ("wake_cos", "起床時刻"),
    }
    cos_keys = {v[0] for v in sincos_pairs.values()}
    feat_idx = {f: i for i, f in enumerate(feature_cols)}

    rows = []
    for i, feat in enumerate(feature_cols):
        if feat in cos_keys:
            continue
        if feat in sincos_pairs:
            cos_key, label = sincos_pairs[feat]
            j = feat_idx[cos_key]
            merged_shap = vals[:, i] + vals[:, j]
            rows.append({
                "feature": label,
                "mean_abs_shap": float(np.mean(np.abs(merged_shap))),
                "mean_shap": float(np.mean(merged_shap)),
            })
        else:
            rows.append({
                "feature": feat,
                "mean_abs_shap": float(np.mean(np.abs(vals[:, i]))),
                "mean_shap": float(np.mean(vals[:, i])),
            })

    result = pd.DataFrame(rows).sort_values("mean_abs_shap", ascending=False)
    return result


if __name__ == "__main__":
    print("=" * 60)
    print("特徴量重要度分析（合成データ 180日）")
    print("=" * 60)

    df = generate_synthetic_data(n_days=180)
    unhealthy = (df["moodScore"] <= 2).sum()
    print(f"\nデータ概要: {len(df)}日, 不調日={unhealthy} ({unhealthy/len(df)*100:.1f}%)\n")

    # --- LR: 標準化係数 ---
    print("-" * 60)
    print("【LR】標準化係数（個別特徴量）")
    print("-" * 60)
    lr_raw = analyze_lr_importance(df)
    for _, row in lr_raw.iterrows():
        bar = "#" * int(row["abs_coef"] * 20)
        print(f"  {row['feature']:22s}  coef={row['coef_std']:+.3f}  |{bar}")

    # --- LR: sin/cos合算後の寄与度 ---
    print()
    print("-" * 60)
    print("【LR】sin/cosペア合算後の平均寄与度（|coef × x_scaled|の平均）")
    print("-" * 60)
    lr_merged = analyze_lr_importance_merged(df)
    total = lr_merged["mean_abs_contrib"].sum()
    for _, row in lr_merged.iterrows():
        pct = row["mean_abs_contrib"] / total * 100
        bar = "#" * int(pct * 0.8)
        print(f"  {row['feature']:22s}  mean|contrib|={row['mean_abs_contrib']:.3f}  ({pct:5.1f}%)  |{bar}")

    # --- LGB: SHAP ---
    print()
    print("-" * 60)
    print("【LightGBM】SHAP値（sin/cosペア合算後）")
    print("-" * 60)
    lgb_result = analyze_lgb_importance(df)
    if lgb_result is not None:
        total_shap = lgb_result["mean_abs_shap"].sum()
        for _, row in lgb_result.iterrows():
            pct = row["mean_abs_shap"] / total_shap * 100
            bar = "#" * int(pct * 0.8)
            print(f"  {row['feature']:22s}  mean|SHAP|={row['mean_abs_shap']:.3f}  ({pct:5.1f}%)  |{bar}")

    print()
    print("=" * 60)
    print("まとめ:")
    print("  - 周期特徴量（曜日/就寝/起床）の合算寄与が全体の何%を占めるかを確認")
    cyclic_features = {"曜日", "就寝時刻", "起床時刻"}
    lr_cyclic = lr_merged[lr_merged["feature"].isin(cyclic_features)]["mean_abs_contrib"].sum()
    lr_total = lr_merged["mean_abs_contrib"].sum()
    print(f"  - LR:  周期特徴量 = {lr_cyclic/lr_total*100:.1f}%")
    if lgb_result is not None:
        lgb_cyclic = lgb_result[lgb_result["feature"].isin(cyclic_features)]["mean_abs_shap"].sum()
        lgb_total = lgb_result["mean_abs_shap"].sum()
        print(f"  - LGB: 周期特徴量 = {lgb_cyclic/lgb_total*100:.1f}%")
    print("=" * 60)
