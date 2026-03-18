"""改善アドバイス生成

要件定義書 Section 2.3 に基づく。
- 個人データの好調日・不調日の統計量から推奨値を自動算出
- 条件を満たすアドバイスをすべて生成（各種類は最大1件）
- 対象: 睡眠時間、就寝時刻、歩数、ストレス、曜日
"""

import numpy as np
import pandas as pd

_DOW_LABELS = ["月", "火", "水", "木", "金", "土", "日"]

# 特徴量名 → アドバイスの param へのマッピング
_FEATURE_TO_ADVICE: dict[str, str] = {
    "sleep_hours_filled": "sleep",
    "sleep_dev": "sleep",
    "bed_sin": "bedtime",
    "bed_cos": "bedtime",
    "steps_filled": "steps",
    "steps_dev": "steps",
    "stress_filled": "stress",
    "sleep_stress": "sleep",
    "steps_stress": "steps",
    "day_sin": "day_of_week",
    "day_cos": "day_of_week",
    "day_sin2": "day_of_week",
    "day_cos2": "day_of_week",
    "is_weekend": "day_of_week",
}


def generate_advice(
    df: pd.DataFrame,
    p_today: float | None,
    days_collected: int = 0,
    unhealthy_count: int = 0,
    contributions: list[dict] | None = None,
) -> list[dict]:
    """個人データに基づく改善アドバイスを生成する。

    返却: [{"param": str, "message": str}, ...]
    """
    if p_today is None:
        return []

    if len(df) < 14:
        return []

    # 不調日/好調日を分離
    valid = df.dropna(subset=["moodScore"]).copy()
    if len(valid) < 14:
        return []

    mean_mood = valid["moodScore"].mean()
    good_days = valid[valid["moodScore"] >= mean_mood + 0.5]
    bad_days = valid[valid["moodScore"] <= mean_mood - 0.5]

    if len(good_days) < 3 or len(bad_days) < 3:
        return []

    advices = []

    # --- 睡眠時間アドバイス ---
    good_sleep = good_days["sleep_hours"].dropna()
    bad_sleep = bad_days["sleep_hours"].dropna()
    if len(good_sleep) >= 3 and len(bad_sleep) >= 3:
        avg_good_sleep = good_sleep.mean()
        avg_bad_sleep = bad_sleep.mean()
        if avg_good_sleep - avg_bad_sleep > 0.3:
            rec_hours = round(avg_good_sleep, 1)
            advices.append({
                "param": "sleep",
                "message": f"{rec_hours}時間の睡眠をとった翌日は体調が安定する傾向があります",
            })

    # --- 就寝時刻アドバイス ---
    _append_bedtime_advice(advices, good_days, bad_days)

    # --- 歩数アドバイス ---
    good_steps = good_days["steps"].dropna()
    bad_steps = bad_days["steps"].dropna()
    if len(good_steps) >= 3 and len(bad_steps) >= 3:
        avg_good_steps = good_steps.mean()
        avg_bad_steps = bad_steps.mean()
        if avg_good_steps - avg_bad_steps > 500:
            threshold = int(round(avg_good_steps / 1000) * 1000)
            advices.append({
                "param": "steps",
                "message": f"{threshold:,}歩以上の日は体調が安定する傾向があります",
            })

    # --- ストレスアドバイス ---
    good_stress = good_days["stress"].dropna()
    bad_stress = bad_days["stress"].dropna()
    if len(good_stress) >= 3 and len(bad_stress) >= 3:
        avg_good_stress = good_stress.mean()
        avg_bad_stress = bad_stress.mean()
        if avg_bad_stress - avg_good_stress > 0.5:
            rec_level = int(round(avg_good_stress))
            # 不調率の差を計算
            low_stress = valid[valid["stress"].fillna(99) <= rec_level]
            high_stress = valid[valid["stress"].fillna(0) > rec_level]
            if len(low_stress) > 0 and len(high_stress) > 0:
                low_bad_rate = (low_stress["moodScore"] <= mean_mood - 1).mean()
                high_bad_rate = (high_stress["moodScore"] <= mean_mood - 1).mean()
                diff_pct = int(round((high_bad_rate - low_bad_rate) * 100))
                if diff_pct > 5:
                    # 具体的な数値は統計的に安定してから表示（設計書 Section 12）
                    if unhealthy_count >= 10 and days_collected >= 60:
                        msg = f"ストレスLv{rec_level}以下の日は不調率が{diff_pct}%低くなっています"
                    else:
                        msg = f"ストレスLv{rec_level}以下の日は不調率が低下する傾向があります"
                    advices.append({
                        "param": "stress",
                        "message": msg,
                    })

    # --- 曜日アドバイス ---
    _append_dow_advice(advices, valid, mean_mood)

    # --- contributions に基づく並べ替え ---
    if contributions and advices:
        boosted = _contribution_params(contributions)
        advices.sort(key=lambda a: (a["param"] not in boosted))

    return advices


# ---------------------------------------------------------------------------
# contributions → アドバイス param 変換
# ---------------------------------------------------------------------------

def _contribution_params(contributions: list[dict]) -> set[str]:
    """contributions の特徴量名を対応するアドバイス param 名の集合に変換する。"""
    params: set[str] = set()
    for c in contributions:
        feat = c.get("feature", "")
        if feat in _FEATURE_TO_ADVICE:
            params.add(_FEATURE_TO_ADVICE[feat])
    return params


# ---------------------------------------------------------------------------
# 就寝時刻アドバイス
# ---------------------------------------------------------------------------

def _time_str_to_minutes(series: pd.Series) -> pd.Series:
    """'HH:mm' → 分(float)。NaN はそのまま保持。"""
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


def _shift_bedtime_minutes(minutes: pd.Series) -> pd.Series:
    """正午未満（深夜〜早朝）を +1440 で補正し、連続的な値にする。"""
    return minutes.where(minutes >= 720, minutes + 1440)


def _minutes_to_time_str(m: float) -> str:
    """分(float) → 'H:MM' 形式。1440 以上は翌日扱いで mod 1440。"""
    m = int(round(m)) % 1440
    return f"{m // 60}:{m % 60:02d}"


def _append_bedtime_advice(
    advices: list[dict],
    good_days: pd.DataFrame,
    bad_days: pd.DataFrame,
) -> None:
    """好調日・不調日の就寝時刻を比較し、30分以上の差があればアドバイスを追加。"""
    if "bed_time" not in good_days.columns:
        return

    good_bed = _shift_bedtime_minutes(_time_str_to_minutes(good_days["bed_time"])).dropna()
    bad_bed = _shift_bedtime_minutes(_time_str_to_minutes(bad_days["bed_time"])).dropna()

    if len(good_bed) < 3 or len(bad_bed) < 3:
        return

    avg_good = good_bed.mean()
    avg_bad = bad_bed.mean()

    # 好調日の方が早寝（値が小さい）で、差が30分以上
    if avg_bad - avg_good < 30:
        return

    rec_time = _minutes_to_time_str(avg_good)
    advices.append({
        "param": "bedtime",
        "message": f"{rec_time}頃の就寝が体調の安定に関連する傾向があります",
    })


# ---------------------------------------------------------------------------
# 曜日アドバイス
# ---------------------------------------------------------------------------

def _append_dow_advice(
    advices: list[dict],
    valid: pd.DataFrame,
    mean_mood: float,
) -> None:
    """曜日別の不調率を計算し、突出して高い曜日があればアドバイスを追加。"""
    df = valid.copy()
    df["_dow"] = pd.to_datetime(df["date_key"]).dt.dayofweek  # 0=Mon

    # 曜日ごとの不調率（mean_mood - 1 以下を不調とする）
    dow_stats = df.groupby("_dow").agg(
        total=("moodScore", "size"),
        bad_count=("moodScore", lambda s: (s <= mean_mood - 1).sum()),
    )
    dow_stats["bad_rate"] = dow_stats["bad_count"] / dow_stats["total"]

    # 各曜日に最低3日分のデータが必要
    dow_stats = dow_stats[dow_stats["total"] >= 3]
    if len(dow_stats) < 3:
        return

    overall_bad_rate = dow_stats["bad_count"].sum() / dow_stats["total"].sum()
    worst_dow = dow_stats["bad_rate"].idxmax()
    worst_rate = dow_stats["bad_rate"].loc[worst_dow]

    # 全体平均より10%ポイント以上高い曜日のみ
    if worst_rate - overall_bad_rate < 0.10:
        return

    label = _DOW_LABELS[worst_dow]
    diff_pct = int(round((worst_rate - overall_bad_rate) * 100))
    advices.append({
        "param": "day_of_week",
        "message": f"{label}曜日は不調率が平均より{diff_pct}%高い傾向があります",
    })
