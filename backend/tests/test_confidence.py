"""信頼度計算のテスト"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from confidence import calculate_confidence


def test_low_confidence_few_days():
    """30日未満は信頼度 low"""
    assert calculate_confidence(20, 3, 0.0) == "low"


def test_low_confidence_few_unhealthy():
    """不調5件未満は信頼度 low"""
    assert calculate_confidence(40, 3, 0.0) == "low"


def test_medium_confidence():
    """30-59日 AND 不調5件以上は信頼度 medium"""
    assert calculate_confidence(45, 7, 0.0) == "medium"


def test_high_confidence():
    """60日以上 AND 不調10件以上は信頼度 high"""
    assert calculate_confidence(60, 10, 0.0) == "high"


def test_downgrade_on_missing():
    """欠損率30%以上で1段階ダウン"""
    assert calculate_confidence(60, 10, 0.35) == "medium"
    assert calculate_confidence(45, 7, 0.35) == "low"


def test_low_stays_low_on_missing():
    """low は欠損率が高くても low のまま"""
    assert calculate_confidence(10, 1, 0.5) == "low"
