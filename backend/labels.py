"""ラベル生成

設計書 Section 4 に基づく不調フラグの生成。
- 不調定義: 過去14日の体調平均と比較し、閾値以下の日を不調とする
- 閾値 = max(mean14 - 1, mean14 - std14)
  → 安定した人は std14 が小さく閾値が引き上げられ、過度な不調判定を防止
- 14日未満は学習行を生成しない
- 3日ラベル: y_3d(t) = OR(y(t+1), y(t+2), y(t+3))
"""

import numpy as np
import pandas as pd


def generate_labels(df: pd.DataFrame) -> pd.DataFrame:
    """不調ラベルを生成する。

    入力 df は date_key 昇順ソート済みで moodScore カラムが必要。

    返却: y_today, y_3d カラムが追加された DataFrame
    """
    df = df.copy().sort_values("date_key").reset_index(drop=True)

    # 過去14日の移動平均（当日を含む）
    df["mood_ma14_current"] = (
        df["moodScore"].rolling(window=14, min_periods=14).mean()
    )

    # 過去14日の移動標準偏差
    df["mood_std14"] = (
        df["moodScore"].rolling(window=14, min_periods=14).std(ddof=0)
    )

    # 不調閾値 = max(mean14 - 1, mean14 - std14)
    # 安定した人（std小）は mean14 - std14 の方が大きく、閾値が引き上げられる
    df["unhealthy_threshold"] = np.where(
        df["mood_ma14_current"].notna(),
        np.maximum(
            df["mood_ma14_current"] - 1,
            df["mood_ma14_current"] - df["mood_std14"],
        ),
        np.nan,
    )

    # 不調フラグ: 当日スコアが閾値未満（std=0のとき全員不調になる問題を防止）
    df["y_today"] = np.where(
        df["unhealthy_threshold"].notna()
        & (df["moodScore"] < df["unhealthy_threshold"]),
        1,
        np.where(df["unhealthy_threshold"].notna(), 0, np.nan),
    )

    # 3日リスクラベル: OR(y(t+1), y(t+2), y(t+3))
    df["y_3d"] = np.nan
    for i in range(len(df) - 3):
        if pd.isna(df.loc[i, "y_today"]):
            continue
        future = df.loc[i + 1 : i + 3, "y_today"]
        if future.isna().any():
            continue
        df.loc[i, "y_3d"] = 1.0 if future.max() >= 1 else 0.0

    # 内部計算用カラムを除外
    df.drop(columns=["mood_ma14_current", "mood_std14", "unhealthy_threshold"], inplace=True)

    return df
