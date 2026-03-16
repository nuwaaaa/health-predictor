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

    # --- 曜日特徴量 ---
    # sin/cosエンコーディング: 円環上の座標に変換し、曜日の周期性を表現
    df["date"] = pd.to_datetime(df["date_key"])
    dow = df["date"].dt.dayofweek  # 0=Mon, 6=Sun
    df["day_sin"] = np.sin(2 * np.pi * dow / 7)
    df["day_cos"] = np.cos(2 * np.pi * dow / 7)
    df["is_weekend"] = dow.isin([5, 6]).astype(int)

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
    # shift(1)で前日までの移動平均を使い、当日値の自己参照を防止
    sleep_mean = df["sleep_hours"].shift(1).rolling(window=7, min_periods=1).mean()
    df["sleep_dev"] = df["sleep_hours_filled"] - _fill_missing(sleep_mean, window=7)

    # --- 歩数特徴量 ---
    # 歩数は t-1 を使用（当日はまだ増えるため）
    df["steps_lag1"] = df["steps"].shift(1)
    df["steps_filled"] = _fill_missing(df["steps_lag1"], window=7)
    steps_mean = df["steps"].shift(1).rolling(window=7, min_periods=1).mean()
    df["steps_dev"] = df["steps_filled"] - _fill_missing(steps_mean, window=7)

    # --- ストレス特徴量（任意入力）---
    df["stress_lag1"] = df["stress"].shift(1)
    df["stress_filled"] = _fill_missing(df["stress_lag1"], window=7)

    return df


def get_feature_columns() -> list[str]:
    """モデルに入力する特徴量カラムのリスト"""
    return [
        "day_sin",
        "day_cos",
        "is_weekend",
        "mood_lag1",
        "mood_ma3",
        "mood_ma7",
        "mood_delta1",
        "mood_dev14",
        "sleep_hours_filled",
        "sleep_dev",
        "steps_filled",
        "steps_dev",
        "stress_filled",
    ]


def _fill_missing(series: pd.Series, window: int = 7) -> pd.Series:
    """過去N日平均で欠損を補完する。最終フォールバックはグローバル平均。"""
    rolling_mean = series.rolling(window=window, min_periods=1).mean()
    global_mean = series.mean()
    # NaN→ローリング平均→グローバル平均の順で補完（0埋めを回避）
    fallback = global_mean if pd.notna(global_mean) else 0
    return series.fillna(rolling_mean).fillna(fallback)
