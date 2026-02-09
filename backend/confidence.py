"""信頼度（Confidence）計算

設計書 Section 11 に基づくルールベース3段階。

| 信頼度 | 条件 |
|-------|------|
| 低    | データ30日未満 OR 不調5件未満 |
| 中    | データ30〜59日 AND 不調5件以上 |
| 高    | データ60日以上 AND 不調10件以上 |

直近7日の入力欠損率が30%以上の場合 → 1段階ダウン
"""

import config


def calculate_confidence(
    days_collected: int,
    unhealthy_count: int,
    recent_missing_rate: float,
) -> str:
    """信頼度を計算する。

    返却: 'low', 'medium', 'high'
    """
    # ベースレベル判定
    if (
        days_collected >= config.CONFIDENCE_HIGH_DAYS
        and unhealthy_count >= config.CONFIDENCE_HIGH_UNHEALTHY
    ):
        level = "high"
    elif (
        days_collected >= config.CONFIDENCE_MEDIUM_DAYS
        and unhealthy_count >= config.CONFIDENCE_MEDIUM_UNHEALTHY
    ):
        level = "medium"
    else:
        level = "low"

    # 欠損率が高い場合は1段階ダウン
    if recent_missing_rate >= config.MISSING_RATE_THRESHOLD:
        if level == "high":
            level = "medium"
        elif level == "medium":
            level = "low"

    return level
