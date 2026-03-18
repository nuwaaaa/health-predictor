"""アドバイス生成のテスト"""

import sys
import os

import pandas as pd
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from advice import generate_advice


def _make_df(n: int = 60) -> pd.DataFrame:
    """好調/不調が混在するテスト用 DataFrame を生成。

    - 月曜(dow=0) は不調(moodScore=2)、それ以外は好調(4)
    - 好調日: bed_time=23:00, 不調日: bed_time=1:30
    """
    rows = []
    base = pd.Timestamp("2025-10-01")
    for i in range(n):
        dt = base + pd.Timedelta(days=i)
        dow = dt.dayofweek
        is_bad = dow == 0  # Monday
        mood = 1 if is_bad else 5
        rows.append({
            "date_key": dt.strftime("%Y-%m-%d"),
            "moodScore": float(mood),
            "sleep_hours": 5.5 if is_bad else 7.5,
            "bed_time": "01:30" if is_bad else "23:00",
            "wake_time": "07:00",
            "steps": 4000 if is_bad else 9000,
            "stress": 4 if is_bad else 2,
        })
    return pd.DataFrame(rows)


class TestBedtimeAdvice:
    """就寝時刻アドバイスのテスト"""

    def test_bedtime_advice_generated(self):
        """好調日が早寝・不調日が遅寝のとき就寝時刻アドバイスが生成される"""
        df = _make_df()
        advices = generate_advice(df, p_today=0.3)
        bedtime = [a for a in advices if a["param"] == "bedtime"]
        assert len(bedtime) == 1
        assert "23:00" in bedtime[0]["message"] or "23:" in bedtime[0]["message"]

    def test_bedtime_advice_not_generated_when_no_diff(self):
        """就寝時刻に差がないときはアドバイスが生成されない"""
        df = _make_df()
        df["bed_time"] = "23:00"  # 全員同じ時刻
        advices = generate_advice(df, p_today=0.3)
        bedtime = [a for a in advices if a["param"] == "bedtime"]
        assert len(bedtime) == 0

    def test_bedtime_advice_not_generated_when_missing(self):
        """bed_time カラムがないときはエラーにならない"""
        df = _make_df()
        df = df.drop(columns=["bed_time"])
        advices = generate_advice(df, p_today=0.3)
        bedtime = [a for a in advices if a["param"] == "bedtime"]
        assert len(bedtime) == 0


class TestDowAdvice:
    """曜日アドバイスのテスト"""

    def test_dow_advice_generated(self):
        """月曜に不調が集中しているとき曜日アドバイスが生成される"""
        df = _make_df()
        advices = generate_advice(df, p_today=0.3)
        dow = [a for a in advices if a["param"] == "day_of_week"]
        assert len(dow) == 1
        assert "月曜日" in dow[0]["message"]

    def test_dow_advice_not_generated_when_uniform(self):
        """不調が均等に分散しているとき曜日アドバイスが生成されない"""
        df = _make_df()
        # すべて同じ moodScore にする
        df["moodScore"] = 3.0
        # 少数を不調にする（均等に分散）
        for i in range(0, len(df), 7):
            df.loc[i, "moodScore"] = 2.0
        advices = generate_advice(df, p_today=0.3)
        dow = [a for a in advices if a["param"] == "day_of_week"]
        assert len(dow) == 0


class TestMultipleAdvices:
    """複数アドバイス同時出力のテスト"""

    def test_all_types_can_appear(self):
        """全種類のアドバイスが同時に出力されうる"""
        df = _make_df()
        advices = generate_advice(df, p_today=0.3)
        params = {a["param"] for a in advices}
        # このテストデータでは sleep, bedtime, steps, stress, day_of_week
        # のすべてが条件を満たす
        assert params == {"sleep", "bedtime", "steps", "stress", "day_of_week"}


class TestExistingAdvice:
    """既存のアドバイス（睡眠時間・歩数・ストレス）が壊れていないことを確認"""

    def test_sleep_advice(self):
        df = _make_df()
        advices = generate_advice(df, p_today=0.3)
        sleep = [a for a in advices if a["param"] == "sleep"]
        assert len(sleep) == 1
        assert "時間" in sleep[0]["message"]

    def test_no_advice_when_too_few_days(self):
        df = _make_df(n=10)
        advices = generate_advice(df, p_today=0.3)
        assert len(advices) == 0

    def test_no_advice_when_p_today_none(self):
        df = _make_df()
        advices = generate_advice(df, p_today=None)
        assert len(advices) == 0


class TestContributionReordering:
    """contributions に基づくアドバイス並べ替えのテスト"""

    def test_reorder_by_contributions(self):
        """contributions に含まれる特徴量のアドバイスが先頭に来る"""
        df = _make_df()
        # contributions なし: 元の順序（sleep, bedtime, steps, stress, day_of_week）
        base = generate_advice(df, p_today=0.3)
        assert len(base) == 5

        # steps_filled が TOP 寄与 → steps が先頭に
        contribs = [{"feature": "steps_filled", "contribution": 0.5}]
        reordered = generate_advice(df, p_today=0.3, contributions=contribs)
        assert reordered[0]["param"] == "steps"

    def test_multiple_boosted_params(self):
        """複数の寄与特徴量に対応するアドバイスが先頭グループに来る"""
        df = _make_df()
        contribs = [
            {"feature": "stress_filled", "contribution": 0.5},
            {"feature": "day_sin", "contribution": 0.3},
        ]
        reordered = generate_advice(df, p_today=0.3, contributions=contribs)
        boosted = {reordered[0]["param"], reordered[1]["param"]}
        assert "stress" in boosted
        assert "day_of_week" in boosted

    def test_no_contributions_preserves_order(self):
        """contributions=None の場合は元の順序を維持"""
        df = _make_df()
        base = generate_advice(df, p_today=0.3)
        no_contrib = generate_advice(df, p_today=0.3, contributions=None)
        assert [a["param"] for a in base] == [a["param"] for a in no_contrib]

    def test_empty_contributions_preserves_order(self):
        """contributions=[] の場合は元の順序を維持"""
        df = _make_df()
        base = generate_advice(df, p_today=0.3)
        empty = generate_advice(df, p_today=0.3, contributions=[])
        assert [a["param"] for a in base] == [a["param"] for a in empty]
