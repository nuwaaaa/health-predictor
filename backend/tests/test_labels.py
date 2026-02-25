"""ラベル生成のテスト"""

import numpy as np
import pandas as pd
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from labels import generate_labels


def _make_df(mood_scores: list[int]) -> pd.DataFrame:
    """テスト用の DataFrame を生成"""
    dates = [f"2026-01-{i+1:02d}" for i in range(len(mood_scores))]
    return pd.DataFrame({"date_key": dates, "moodScore": mood_scores})


def test_no_labels_under_14_days():
    """14日未満では y_today が生成されないことを確認"""
    df = _make_df([3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3])
    result = generate_labels(df)
    assert result["y_today"].isna().all()


def test_labels_from_14_days():
    """14日目から y_today が生成されることを確認"""
    # 14日間のデータ：平均は約3.5
    scores = [3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4]
    df = _make_df(scores)
    result = generate_labels(df)
    # 14日目（index=13）はラベルが生成される
    assert not pd.isna(result.loc[13, "y_today"])


def test_unhealthy_detection():
    """不調フラグが正しく立つことを確認"""
    # 14日間は平均的、15日目に大きく低下
    scores = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1]
    df = _make_df(scores)
    result = generate_labels(df)
    # 15日目(index=14): mood=1, 14日平均≈3.7 → 1 <= 3.7-1=2.7 → 不調
    assert result.loc[14, "y_today"] == 1


def test_healthy_detection():
    """健康な日が正しく 0 になることを確認"""
    scores = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
    df = _make_df(scores)
    result = generate_labels(df)
    # 全部3なので14日平均も3、3 <= 3-1=2 は False → 健康
    assert result.loc[14, "y_today"] == 0


def test_3d_label():
    """3日ラベルが OR(t+1, t+2, t+3) で生成されることを確認"""
    # 17日分のデータ
    scores = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1]
    df = _make_df(scores)
    result = generate_labels(df)
    # index=13 の y_3d: index 14,15,16 のうち index 16 が不調 → y_3d=1
    assert result.loc[13, "y_3d"] == 1.0
