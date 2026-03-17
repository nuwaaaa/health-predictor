"""特徴量生成のテスト"""

import numpy as np
import pandas as pd
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from features import build_features, get_feature_columns


def _make_df(n: int = 20) -> pd.DataFrame:
    """テスト用 DataFrame を生成"""
    dates = [f"2026-01-{i+1:02d}" for i in range(n)]
    return pd.DataFrame(
        {
            "date_key": dates,
            "moodScore": [3 + (i % 3) for i in range(n)],
            "sleep_hours": [7.0 + (i % 3) * 0.5 for i in range(n)],
            "bed_time": [
                f"{23 if i % 2 == 0 else 0}:{i % 6 * 10:02d}"
                if i % 5 != 0
                else None
                for i in range(n)
            ],
            "wake_time": [
                f"07:{i % 6 * 10:02d}" if i % 7 != 0 else None
                for i in range(n)
            ],
            "steps": [8000 + i * 100 for i in range(n)],
            "stress": [None if i % 4 == 0 else 2 + (i % 3) for i in range(n)],
        }
    )


def test_build_features_returns_all_columns():
    """全特徴量カラムが生成されることを確認"""
    df = _make_df()
    result = build_features(df)
    for col in get_feature_columns():
        assert col in result.columns, f"Missing column: {col}"


def test_mood_lag1_no_leak():
    """mood_lag1 が t-1 のスコアであること（リーク防止）"""
    df = _make_df()
    result = build_features(df)
    # index 0 の mood_lag1 は NaN（前日データなし）
    assert pd.isna(result.loc[0, "mood_lag1"])
    # index 1 の mood_lag1 は index 0 の moodScore
    assert result.loc[1, "mood_lag1"] == df.loc[0, "moodScore"]


def test_steps_uses_lag1():
    """歩数が t-1 を使用していること"""
    df = _make_df()
    result = build_features(df)
    # index 0 の steps_lag1 は NaN（前日データなし）→ _fill_missing でグローバル平均に補完
    # index 1 の steps_filled は index 0 の steps を基にしている
    assert result.loc[1, "steps_filled"] == df.loc[0, "steps"]


def test_weekend_flag():
    """休日フラグが正しいことを確認"""
    df = _make_df()
    result = build_features(df)
    # 2026-01-03 は Saturday → is_weekend=1
    sat_row = result[result["date_key"] == "2026-01-03"]
    assert len(sat_row) == 1
    assert sat_row.iloc[0]["is_weekend"] == 1


def test_sleep_missing_filled():
    """睡眠欠損が補完されることを確認（*_missing フラグは設計書 3/16 で廃止済み）"""
    df = _make_df()
    df.loc[5, "sleep_hours"] = None
    result = build_features(df)
    # 欠損はローリング平均で補完され、NaN にならないこと
    assert pd.notna(result.loc[5, "sleep_hours_filled"])


def test_stress_missing_filled():
    """ストレスの欠損が補完されることを確認"""
    df = _make_df()
    result = build_features(df)
    # stress_filled should not have NaN (except possibly the first row)
    assert result["stress_filled"].isna().sum() <= 1
