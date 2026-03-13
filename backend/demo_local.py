"""ローカルテスト用スクリプト

Firestore なしで100日分のテストデータを生成し、
パイプラインのロジック（特徴量→ラベル→モデル→予測）を実行して結果を表示する。

使い方:
  cd backend && python demo_local.py
"""

import random
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

from confidence import calculate_confidence
from features import build_features, get_feature_columns
from labels import generate_labels
from models import train_and_predict


def generate_test_data(n_days: int = 100, seed: int = 42) -> pd.DataFrame:
    """100日分のリアルなテストデータを生成する。"""
    rng = random.Random(seed)
    today = datetime.now()

    # 不調期（2〜3週間ごとに2〜3日続く）
    sick_days = set()
    for start in [8, 25, 48, 67, 85]:
        duration = rng.randint(2, 3)
        for d in range(duration):
            sick_days.add(start + d)

    rows = []
    for i in range(n_days):
        day = today - timedelta(days=n_days - 1 - i)
        date_key = day.strftime("%Y-%m-%d")
        is_weekend = day.weekday() >= 5
        days_ago = n_days - 1 - i

        # 体調スコア
        if days_ago in sick_days:
            mood = rng.randint(1, 2)
        elif is_weekend:
            mood = rng.choice([3, 4, 4, 5])
        else:
            mood = rng.choice([2, 3, 3, 4, 4, 5])

        # 睡眠
        base_sleep = 6.5 + rng.random() * 2.0
        if mood <= 2:
            base_sleep -= 1.0 + rng.random()
        if is_weekend:
            base_sleep += 0.5
        sleep_hours = round(base_sleep, 1)

        # 歩数
        steps = rng.randint(2000, 5000) if mood <= 2 else rng.randint(5000, 13000)

        # ストレス（20%欠損）
        stress = None
        if rng.random() > 0.2:
            stress = rng.randint(3, 5) if mood <= 2 else rng.randint(1, 3)

        rows.append({
            "date_key": date_key,
            "moodScore": mood,
            "sleep_hours": sleep_hours,
            "steps": steps,
            "stress": stress,
        })

    return pd.DataFrame(rows)


def main():
    print("=" * 60)
    print("  体調予測パイプライン ローカルデモ")
    print("=" * 60)

    # テストデータ生成
    df = generate_test_data(100)
    print(f"\n[データ] {len(df)}日分のテストデータを生成")
    print(f"  期間: {df['date_key'].iloc[0]} 〜 {df['date_key'].iloc[-1]}")
    print(f"  体調分布: {dict(df['moodScore'].value_counts().sort_index())}")

    # ラベル生成
    df = generate_labels(df)
    unhealthy_count = int((df["y_today"] == 1).sum())
    total_labeled = int(df["y_today"].notna().sum())
    print(f"\n[ラベル] 不調日数: {unhealthy_count} / {total_labeled} 日 "
          f"({unhealthy_count / max(total_labeled, 1) * 100:.1f}%)")

    # 特徴量生成
    df = build_features(df)
    feature_cols = get_feature_columns()
    print(f"\n[特徴量] {len(feature_cols)} 特徴量を生成")
    for col in feature_cols:
        na_count = df[col].isna().sum()
        if na_count > 0:
            print(f"  {col}: {na_count} 件欠損")

    # --- 今日のリスク予測 ---
    print("\n" + "-" * 60)
    print("  今日のリスク予測")
    print("-" * 60)

    result_today = train_and_predict(
        df=df,
        feature_cols=feature_cols,
        target_col="y_today",
        days_collected=len(df),
        unhealthy_count=unhealthy_count,
    )
    p_today = result_today["probability"]
    model_type = result_today["model_type"]
    auc = result_today["auc"]
    pr_auc = result_today["pr_auc"]

    if p_today is not None:
        print(f"\n  不調確率: {p_today * 100:.1f}%")
        print(f"  モデル:   {model_type}")
        cv_pr_auc_mean = result_today.get("cv_pr_auc_mean")
        cv_pr_auc_std = result_today.get("cv_pr_auc_std")
        cv_folds = result_today.get("cv_folds", 0)
        if cv_pr_auc_mean is not None:
            print(f"  CV PR-AUC: {cv_pr_auc_mean:.3f}±{cv_pr_auc_std:.3f} ({cv_folds} folds)")
        if auc is not None:
            print(f"  ROC-AUC:  {auc:.3f}")
        if pr_auc is not None:
            print(f"  PR-AUC:   {pr_auc:.3f}")
    else:
        print("  予測不可（データ不足）")

    # --- 3日リスク予測 ---
    print("\n" + "-" * 60)
    print("  3日リスク予測")
    print("-" * 60)

    if len(df) >= 60 and unhealthy_count >= 10:
        result_3d = train_and_predict(
            df=df,
            feature_cols=feature_cols,
            target_col="y_3d",
            days_collected=len(df),
            unhealthy_count=unhealthy_count,
        )
        p_3d = result_3d["probability"]
        if p_3d is not None:
            print(f"\n  3日不調確率: {p_3d * 100:.1f}%")
            print(f"  モデル:     {result_3d['model_type']}")
            cv_mean_3d = result_3d.get("cv_pr_auc_mean")
            cv_std_3d = result_3d.get("cv_pr_auc_std")
            cv_folds_3d = result_3d.get("cv_folds", 0)
            if cv_mean_3d is not None:
                print(f"  CV PR-AUC: {cv_mean_3d:.3f}±{cv_std_3d:.3f} ({cv_folds_3d} folds)")
            if result_3d["auc"] is not None:
                print(f"  ROC-AUC:   {result_3d['auc']:.3f}")
            if result_3d["pr_auc"] is not None:
                print(f"  PR-AUC:    {result_3d['pr_auc']:.3f}")
        else:
            print("  予測不可")
    else:
        print(f"  未開放（条件: 60日以上 AND 不調10件以上）")
        print(f"  現在: {len(df)}日, 不調{unhealthy_count}件")

    # --- 信頼度 ---
    recent_7 = df.tail(7)
    missing_rate = float(recent_7["moodScore"].isna().sum() / len(recent_7))
    confidence = calculate_confidence(len(df), unhealthy_count, missing_rate)
    print(f"\n  信頼度:   {confidence}")
    print(f"  欠損率:   {missing_rate * 100:.0f}%")

    # --- UI 表示シミュレーション ---
    print("\n" + "=" * 60)
    print("  UI 表示シミュレーション")
    print("=" * 60)

    if p_today is not None:
        pct = p_today * 100
        if pct >= 60:
            risk_label = "高め"
            bar = "████████"
        elif pct >= 40:
            risk_label = "やや注意"
            bar = "██████"
        elif pct >= 20:
            risk_label = "低め"
            bar = "████"
        else:
            risk_label = "良好"
            bar = "██"

        conf_label = {"high": "高", "medium": "中", "low": "低"}[confidence]

        print(f"""
  ┌─────────────────────────────────────────┐
  │  今日の不調リスク          信頼度：{conf_label}   │
  │                                         │
  │   {pct:5.1f}%  {risk_label:<6}                      │
  │   {bar:<20}                     │
  │                                         │""")

        if p_3d is not None:
            pct_3d = p_3d * 100
            print(f"  │  ───────────────────────────────────── │")
            print(f"  │  📅 3日間リスク              {pct_3d:5.1f}%    │")

        if confidence == "low":
            print(f"  │  ⓘ まだ学習中の参考値です              │")

        print(f"  └─────────────────────────────────────────┘")

    # 直近7日の体調推移
    print(f"\n  直近7日の体調:")
    for _, row in df.tail(7).iterrows():
        mood = int(row["moodScore"])
        emojis = {1: "😣", 2: "😕", 3: "😐", 4: "🙂", 5: "😄"}
        y = row.get("y_today")
        flag = " ⚠不調" if y == 1 else ""
        print(f"    {row['date_key']}  {emojis.get(mood, '?')} {mood}{flag}")

    print()


if __name__ == "__main__":
    main()
