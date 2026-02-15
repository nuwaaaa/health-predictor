"""ラベル生成

設計書 Section 4 に基づく不調フラグの生成。
- 不調定義: 過去14日の体調平均と比較し、平均より1段階以上低い日を不調とする
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

    # 不調フラグ: 当日スコアが14日平均より1以上低い
    df["y_today"] = np.where(
        df["mood_ma14_current"].notna()
        & (df["moodScore"] <= df["mood_ma14_current"] - 1),
        1,
        np.where(df["mood_ma14_current"].notna(), 0, np.nan),
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

    # mood_ma14_current は内部計算用なので除外
    df.drop(columns=["mood_ma14_current"], inplace=True)

    return df
