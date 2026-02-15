"""特徴量エンジニアリング

設計書 Section 6 に基づく特徴量生成。
リーク防止ルール: x(t) に使ってよい体調系は t-1 以前のみ。
"""

import numpy as np
import pandas as pd


def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """日次ログ DataFrame から特徴量を生成する。

    入力 df は date_key 昇順にソート済みを想定。
    カラム: date_key, moodScore, sleep_hours, steps, stress

    返却: 特徴量テーブル（date_key, 各特徴量カラム）
    """
    df = df.copy().sort_values("date_key").reset_index(drop=True)

    # --- 曜日・休日フラグ ---
    df["date"] = pd.to_datetime(df["date_key"])
    df["day_of_week"] = df["date"].dt.dayofweek  # 0=Mon, 6=Sun
    df["is_weekend"] = df["day_of_week"].isin([5, 6]).astype(int)

    # --- 体調の時系列特徴量（t-1 以前のみ使用）---
    df["mood_lag1"] = df["moodScore"].shift(1)  # mood(t-1)
    df["mood_ma3"] = (
        df["moodScore"].shift(1).rolling(window=3, min_periods=1).mean()
    )  # ma3(t-1)
    df["mood_ma7"] = (
        df["moodScore"].shift(1).rolling(window=7, min_periods=1).mean()
    )  # ma7(t-1)
    df["mood_delta1"] = df["moodScore"].shift(1) - df["moodScore"].shift(2)  # delta1(t-1)
    df["mood_ma14"] = (
        df["moodScore"].shift(1).rolling(window=14, min_periods=7).mean()
    )
    df["mood_dev14"] = df["moodScore"].shift(1) - df["mood_ma14"]  # dev14(t-1)

    # --- 睡眠特徴量 ---
    # 睡眠は当日起床分 (date_key=t) を使用可能
    df["sleep_hours_filled"] = _fill_missing(df["sleep_hours"], window=7)
    df["sleep_missing"] = df["sleep_hours"].isna().astype(int)
    sleep_mean = df["sleep_hours"].rolling(window=7, min_periods=1).mean()
    df["sleep_dev"] = df["sleep_hours_filled"] - sleep_mean

    # --- 歩数特徴量 ---
    # 歩数は t-1 を使用（当日はまだ増えるため）
    df["steps_lag1"] = df["steps"].shift(1)
    df["steps_filled"] = _fill_missing(df["steps_lag1"], window=7)
    df["steps_missing"] = df["steps_lag1"].isna().astype(int)
    steps_mean = df["steps"].shift(1).rolling(window=7, min_periods=1).mean()
    df["steps_dev"] = df["steps_filled"] - steps_mean

    # --- ストレス特徴量（任意入力）---
    df["stress_lag1"] = df["stress"].shift(1)
    df["stress_filled"] = _fill_missing(df["stress_lag1"], window=7)
    df["stress_missing"] = df["stress_lag1"].isna().astype(int)

    return df


def get_feature_columns() -> list[str]:
    """モデルに入力する特徴量カラムのリスト"""
    return [
        "day_of_week",
        "is_weekend",
        "mood_lag1",
        "mood_ma3",
        "mood_ma7",
        "mood_delta1",
        "mood_dev14",
        "sleep_hours_filled",
        "sleep_missing",
        "sleep_dev",
        "steps_filled",
        "steps_missing",
        "steps_dev",
        "stress_filled",
        "stress_missing",
    ]


def _fill_missing(series: pd.Series, window: int = 7) -> pd.Series:
    """過去N日平均で欠損を補完する。"""
    rolling_mean = series.rolling(window=window, min_periods=1).mean()
    return series.fillna(rolling_mean).fillna(0)
