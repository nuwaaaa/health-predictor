"""改善アドバイス生成

要件定義書 Section 2.3 に基づく。
- リスクが高い場合、今日～明日に変えられる行動に限定
- 個人データの好調日・不調日の統計量から推奨値を自動算出
- 最大2件のアドバイスを生成
- 対象: 睡眠時間、歩数、ストレス（曜日・過去の体調は対象外）
"""

import pandas as pd


def generate_advice(
    df: pd.DataFrame,
    p_today: float | None,
    risk_threshold: float = 0.3,
) -> list[dict]:
    """個人データに基づく改善アドバイスを最大2件生成する。

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

    # --- 睡眠アドバイス ---
    good_sleep = good_days["sleep_hours"].dropna()
    bad_sleep = bad_days["sleep_hours"].dropna()
    if len(good_sleep) >= 3 and len(bad_sleep) >= 3:
        avg_good_sleep = good_sleep.mean()
        avg_bad_sleep = bad_sleep.mean()
        if avg_good_sleep - avg_bad_sleep > 0.3:
            rec_hours = round(avg_good_sleep, 1)
            # 推奨就寝時刻 = 起床7:00想定 - 推奨睡眠時間
            rec_bed_hour = int(24 + 7 - rec_hours) % 24
            rec_bed_min = int((rec_hours % 1) * 60)
            bed_time = f"{rec_bed_hour}:{rec_bed_min:02d}"
            advices.append({
                "param": "sleep",
                "message": f"あなたの好調日は平均{rec_hours}時間の睡眠です。今夜は{bed_time}頃までに就寝がおすすめです",
            })

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
            total = len(valid)
            low_stress = valid[valid["stress"].fillna(99) <= rec_level]
            high_stress = valid[valid["stress"].fillna(0) > rec_level]
            if len(low_stress) > 0 and len(high_stress) > 0:
                low_bad_rate = (low_stress["moodScore"] <= mean_mood - 1).mean()
                high_bad_rate = (high_stress["moodScore"] <= mean_mood - 1).mean()
                diff_pct = int(round((high_bad_rate - low_bad_rate) * 100))
                if diff_pct > 5:
                    advices.append({
                        "param": "stress",
                        "message": f"ストレスLv{rec_level}以下の日は不調率が{diff_pct}%低くなっています",
                    })

    return advices[:2]
