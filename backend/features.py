"""特徴量エンジニアリング

設計書 Section 6 に基づく特徴量生成。
リーク防止ルール: x(t) に使ってよい体調系は t-1 以前のみ。
"""

import numpy as np
import pandas as pd

import config


def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """日次ログ DataFrame から特徴量を生成する。

    入力 df は date_key 昇順にソート済みを想定。
    カラム: date_key, moodScore, sleep_hours, bed_time, wake_time, steps, stress

    返却: 特徴量テーブル（date_key, 各特徴量カラム）
    """
    df = df.copy().sort_values("date_key").reset_index(drop=True)

    # --- 曜日特徴量 ---
    # sin/cosエンコーディング: 円環上の座標に変換し、曜日の周期性を表現
    df["date"] = pd.to_datetime(df["date_key"])
    dow = df["date"].dt.dayofweek  # 0=Mon, 6=Sun
    df["day_sin"] = np.sin(2 * np.pi * dow / 7)
    df["day_cos"] = np.cos(2 * np.pi * dow / 7)
    df["day_sin2"] = np.sin(4 * np.pi * dow / 7)
    df["day_cos2"] = np.cos(4 * np.pi * dow / 7)
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
    df["sleep_hours_filled"] = _fill_missing(
        df["sleep_hours"], window=7, default=config.FEATURE_DEFAULTS["sleep_hours"])
    # shift(1)で前日までの移動平均を使い、当日値の自己参照を防止
    sleep_mean = df["sleep_hours"].shift(1).rolling(window=7, min_periods=1).mean()
    df["sleep_dev"] = df["sleep_hours_filled"] - _fill_missing(
        sleep_mean, window=7, default=config.FEATURE_DEFAULTS["sleep_hours"])

    # --- 就寝・起床時刻の周期特徴量 ---
    bed_minutes = _time_str_to_minutes(df["bed_time"])
    wake_minutes = _time_str_to_minutes(df["wake_time"])

    # 就寝時刻: 正午未満(深夜〜早朝)を+1440で補正してローリング平均を正しく計算
    bed_shifted = bed_minutes.where(bed_minutes >= 720, bed_minutes + 1440)
    bed_filled = _fill_missing(bed_shifted, window=7)
    df["bed_sin"] = np.sin(2 * np.pi * bed_filled / 1440)
    df["bed_cos"] = np.cos(2 * np.pi * bed_filled / 1440)

    # 起床時刻: 06:00-10:00付近に集中、境界問題なし
    wake_filled = _fill_missing(wake_minutes, window=7)
    df["wake_sin"] = np.sin(2 * np.pi * wake_filled / 1440)
    df["wake_cos"] = np.cos(2 * np.pi * wake_filled / 1440)

    # --- 歩数特徴量 ---
    # 歩数は t-1 を使用（当日はまだ増えるため）
    df["steps_lag1"] = df["steps"].shift(1)
    df["steps_filled"] = _fill_missing(
        df["steps_lag1"], window=7, default=config.FEATURE_DEFAULTS["steps"])
    steps_mean = df["steps"].shift(1).rolling(window=7, min_periods=1).mean()
    df["steps_dev"] = df["steps_filled"] - _fill_missing(
        steps_mean, window=7, default=config.FEATURE_DEFAULTS["steps"])

    # --- ストレス特徴量（任意入力）---
    df["stress_lag1"] = df["stress"].shift(1)
    df["stress_filled"] = _fill_missing(
        df["stress_lag1"], window=7, default=config.FEATURE_DEFAULTS["stress"])

    # --- 交互作用項（LRでの非線形パターン捕捉用）---
    df["sleep_stress"] = df["sleep_hours_filled"] * df["stress_filled"]
    df["steps_stress"] = df["steps_filled"] * df["stress_filled"]

    return df


def get_feature_columns() -> list[str]:
    """モデルに入力する特徴量カラムのリスト"""
    return [
        "day_sin",
        "day_cos",
        "day_sin2",
        "day_cos2",
        "is_weekend",
        "mood_lag1",
        "mood_ma3",
        "mood_ma7",
        "mood_delta1",
        "mood_dev14",
        "sleep_hours_filled",
        "sleep_dev",
        "bed_sin",
        "bed_cos",
        "wake_sin",
        "wake_cos",
        "steps_filled",
        "steps_dev",
        "stress_filled",
        "sleep_stress",
        "steps_stress",
    ]


def _time_str_to_minutes(series: pd.Series) -> pd.Series:
    """'HH:mm' 文字列の Series を分(float)に変換する。None/NaN はそのまま保持。"""
    def _parse(val):
        if pd.isna(val) or not isinstance(val, str):
            return np.nan
        parts = val.split(":")
        if len(parts) != 2:
            return np.nan
        try:
            return int(parts[0]) * 60 + int(parts[1])
        except ValueError:
            return np.nan
    return series.apply(_parse)


def _fill_missing(series: pd.Series, window: int = 7, default: float | None = None) -> pd.Series:
    """過去N日平均で欠損を補完する。最終フォールバックはグローバル平均→デフォルト値。"""
    rolling_mean = series.rolling(window=window, min_periods=1).mean()
    global_mean = series.mean()
    result = series.fillna(rolling_mean).fillna(global_mean)
    if default is not None:
        return result.fillna(default)
    return result.fillna(0)
