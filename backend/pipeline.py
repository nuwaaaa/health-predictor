"""バッチパイプライン

毎日 03:30 JST に Cloud Run で実行。
1. アクティブユーザーを抽出
2. 各ユーザーのデータを取得
3. 特徴量生成 → ラベル生成 → モデル学習 → 予測
4. 予測結果と model_status を Firestore に書き戻す
"""

import logging
from datetime import datetime, timedelta, timezone

import numpy as np
import pandas as pd
from google.cloud import firestore

import config
from advice import generate_advice
from confidence import calculate_confidence
from features import build_features, get_feature_columns
from labels import generate_labels
from models import train_and_predict

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))


def run_batch():
    """バッチ処理のエントリーポイント"""
    db = firestore.Client()
    today = datetime.now(JST).strftime("%Y-%m-%d")
    logger.info("Batch started for %s", today)

    users = _get_active_users(db)
    logger.info("Active users: %d", len(users))

    for uid in users:
        try:
            _process_user(db, uid, today)
        except Exception:
            logger.exception("Failed to process user %s", uid)

    logger.info("Batch completed")


def _get_active_users(db: firestore.Client) -> list[str]:
    """直近N日以内にデータ更新があったユーザーを抽出する。"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=config.ACTIVE_USER_DAYS)

    users_ref = db.collection("users")
    user_docs = users_ref.stream()

    active_uids = []
    for user_doc in user_docs:
        uid = user_doc.id
        # 直近のdailyドキュメントを1件確認
        recent = (
            users_ref.document(uid)
            .collection("daily")
            .order_by("updatedAt", direction=firestore.Query.DESCENDING)
            .limit(1)
            .stream()
        )
        for doc in recent:
            data = doc.to_dict()
            updated_at = data.get("updatedAt")
            if updated_at and updated_at >= cutoff:
                active_uids.append(uid)
                break

    return active_uids


def _process_user(db: firestore.Client, uid: str, today: str):
    """1ユーザー分の処理"""
    logger.info("Processing user: %s", uid)

    # 日次データを全件取得
    daily_ref = db.collection("users").document(uid).collection("daily")
    docs = daily_ref.order_by("__name__").stream()

    rows = []
    for doc in docs:
        data = doc.to_dict()
        sleep_data = data.get("sleep", {})
        summary = data.get("sleepSummary", {})

        # sleepSummary がある場合はセグメントベースの値を使用
        # 無い場合（既存データ）は sleep フィールドからフォールバック
        if summary:
            sleep_hours = summary.get("longestBlockMin", 0) / 60.0 if summary.get("longestBlockMin") else sleep_data.get("durationHours")
            bed_time = summary.get("longestBlockStart") or sleep_data.get("bedTime")
            wake_time = summary.get("longestBlockEnd") or sleep_data.get("wakeTime")
            nap_total_min = summary.get("napTotalMin", 0)
            sleep_fragmentation = summary.get("segmentCount", 1)
            total_sleep_min = summary.get("totalSleepMin", 0)
            total_sleep_hours = total_sleep_min / 60.0 if total_sleep_min else sleep_hours
        else:
            sleep_hours = sleep_data.get("durationHours")
            bed_time = sleep_data.get("bedTime")
            wake_time = sleep_data.get("wakeTime")
            nap_total_min = 0
            sleep_fragmentation = 1
            total_sleep_hours = sleep_hours  # 既存データ: 主睡眠=合計

        rows.append(
            {
                "date_key": doc.id,
                "moodScore": data.get("moodScore"),  # Noneも含める（欠損率算出のため）
                "sleep_hours": sleep_hours,
                "bed_time": bed_time,       # "HH:mm" or None
                "wake_time": wake_time,     # "HH:mm" or None
                "nap_total_min": nap_total_min,
                "sleep_fragmentation": sleep_fragmentation,
                "total_sleep_hours": total_sleep_hours,
                "steps": data.get("steps"),
                "stress": data.get("stress"),
            }
        )

    if not rows:
        logger.info("No data for user %s", uid)
        return

    df = pd.DataFrame(rows).sort_values("date_key").reset_index(drop=True)
    # moodScore が1件もない場合はスキップ
    if df["moodScore"].dropna().empty:
        logger.info("No mood data for user %s", uid)
        return
    days_collected = int(df["moodScore"].notna().sum())

    # 14日未満は予測を生成しない
    if days_collected < config.MIN_DAYS_TODAY:
        logger.info(
            "User %s has %d days (< %d), skipping prediction",
            uid,
            days_collected,
            config.MIN_DAYS_TODAY,
        )
        _update_model_status(
            db, uid, days_collected, unhealthy_count=0,
            recent_missing_rate=0.0, model_type="logistic",
            confidence_level="low", ready=False,
        )
        return

    # ラベル生成
    df = generate_labels(df)
    unhealthy_count = int((df["y_today"] == 1).sum())

    # 特徴量生成
    df = build_features(df)

    # 直近7日の入力欠損率
    recent_7 = df.tail(7)
    recent_missing_rate = float(recent_7["moodScore"].isna().sum() / len(recent_7))

    # --- 今日のリスク予測 ---
    feature_cols = get_feature_columns()
    today_result = train_and_predict(
        df=df,
        feature_cols=feature_cols,
        target_col="y_today",
        days_collected=days_collected,
        unhealthy_count=unhealthy_count,
    )

    # --- 3日リスク予測 ---
    p3d = None
    if (
        days_collected >= config.MIN_DAYS_3D
        and unhealthy_count >= config.MIN_UNHEALTHY_3D
    ):
        result_3d = train_and_predict(
            df=df,
            feature_cols=feature_cols,
            target_col="y_3d",
            days_collected=days_collected,
            unhealthy_count=unhealthy_count,
        )
        p3d = result_3d["probability"]

    # 信頼度計算
    confidence_level = calculate_confidence(
        days_collected=days_collected,
        unhealthy_count=unhealthy_count,
        recent_missing_rate=recent_missing_rate,
    )

    # 不調基準の算出: max(mean14 - 1, mean14 - std14)
    recent_14 = df["moodScore"].dropna().tail(14)
    mood_mean_14 = float(recent_14.mean()) if len(recent_14) > 0 else None
    if mood_mean_14 is not None and len(recent_14) >= 14:
        std_14 = float(recent_14.std(ddof=0))
        unhealthy_threshold = round(max(mood_mean_14 - 1, mood_mean_14 - std_14), 2)
    else:
        unhealthy_threshold = round(mood_mean_14 - 1, 2) if mood_mean_14 is not None else None

    model_type = today_result["model_type"]
    model_version = f"{model_type}_v1"

    # 改善アドバイス生成
    advices = generate_advice(
        df, today_result["probability"],
        days_collected=days_collected,
        unhealthy_count=unhealthy_count,
        contributions=today_result.get("contributions", []),
    )

    # 特徴量寄与度TOP3
    contributions = today_result.get("contributions", [])

    # クライアント側推論用モデルパラメータ（ロジスティック回帰のみ）
    model_params = today_result.get("model_params")

    # 予測結果を Firestore に保存
    _save_prediction(
        db=db,
        uid=uid,
        date_key=today,
        p_today=today_result["probability"],
        p_3d=p3d,
        confidence=confidence_level,
        model_version=model_version,
        contributions=contributions,
        advices=advices,
    )

    # model_status を更新
    _update_model_status(
        db=db,
        uid=uid,
        days_collected=days_collected,
        unhealthy_count=unhealthy_count,
        recent_missing_rate=recent_missing_rate,
        model_type=model_type,
        confidence_level=confidence_level,
        ready=True,
        mood_mean_14=mood_mean_14,
        unhealthy_threshold=unhealthy_threshold,
        model_params=model_params,
    )

    # バッチ評価ログを保存（設計書 Section 13.3）
    _save_batch_log(
        db=db,
        uid=uid,
        date_key=today,
        days_collected=days_collected,
        unhealthy_count=unhealthy_count,
        model_type=model_type,
        val_auc=today_result["auc"],
        val_pr_auc=today_result["pr_auc"],
        brier_score=today_result.get("brier_score"),
        cv_pr_auc_mean=today_result.get("cv_pr_auc_mean"),
        cv_pr_auc_std=today_result.get("cv_pr_auc_std"),
        cv_folds=today_result.get("cv_folds", 0),
        recent_missing_rate=recent_missing_rate,
        mood_mean_14=mood_mean_14,
        unhealthy_threshold=unhealthy_threshold,
        df=df,
    )

    logger.info(
        "User %s: pToday=%.3f, p3d=%s, model=%s, confidence=%s, cv_pr_auc=%.3f±%.3f (%d folds)",
        uid,
        today_result["probability"] or 0,
        f"{p3d:.3f}" if p3d is not None else "N/A",
        model_type,
        confidence_level,
        today_result.get("cv_pr_auc_mean") or 0,
        today_result.get("cv_pr_auc_std") or 0,
        today_result.get("cv_folds", 0),
    )


def _save_prediction(
    db: firestore.Client,
    uid: str,
    date_key: str,
    p_today: float | None,
    p_3d: float | None,
    confidence: str,
    model_version: str,
    contributions: list[dict] | None = None,
    advices: list[dict] | None = None,
):
    """予測結果を Firestore に保存"""
    pred_ref = (
        db.collection("users")
        .document(uid)
        .collection("predictions")
        .document(date_key)
    )

    data = {
        "confidence": confidence,
        "generatedAt": firestore.SERVER_TIMESTAMP,
        "modelVersion": model_version,
        "source": "batch",
        "provisional": False,
    }
    if p_today is not None:
        data["pToday"] = round(p_today, 4)
    if p_3d is not None:
        data["p3d"] = round(p_3d, 4)
    if contributions:
        data["contributions"] = contributions
    if advices:
        data["advices"] = advices

    pred_ref.set(data)


def _update_model_status(
    db: firestore.Client,
    uid: str,
    days_collected: int,
    unhealthy_count: int,
    recent_missing_rate: float,
    model_type: str,
    confidence_level: str,
    ready: bool,
    mood_mean_14: float | None = None,
    unhealthy_threshold: float | None = None,
    model_params: dict | None = None,
):
    """model_status を更新"""
    status_ref = (
        db.collection("users")
        .document(uid)
        .collection("model_status")
        .document("current")
    )

    data = {
        "daysCollected": days_collected,
        "daysRequired": config.MIN_DAYS_TODAY,
        "ready": ready,
        "unhealthyCount": unhealthy_count,
        "recentMissingRate": round(recent_missing_rate, 3),
        "modelType": model_type,
        "confidenceLevel": confidence_level,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    if mood_mean_14 is not None:
        data["moodMean14"] = round(mood_mean_14, 2)
    if unhealthy_threshold is not None:
        data["unhealthyThreshold"] = unhealthy_threshold
    if model_params is not None:
        data["modelParams"] = model_params

    status_ref.set(data, merge=True)


def _save_batch_log(
    db: firestore.Client,
    uid: str,
    date_key: str,
    days_collected: int,
    unhealthy_count: int,
    model_type: str,
    val_auc: float | None,
    val_pr_auc: float | None,
    brier_score: float | None,
    cv_pr_auc_mean: float | None,
    cv_pr_auc_std: float | None,
    cv_folds: int,
    recent_missing_rate: float,
    mood_mean_14: float | None,
    unhealthy_threshold: float | None,
    df: pd.DataFrame,
):
    """バッチ評価ログを保存（設計書 Section 13.3）"""
    log_ref = (
        db.collection("users")
        .document(uid)
        .collection("batch_logs")
        .document(date_key)
    )

    # 直近N日の平均睡眠・歩数
    recent = df.tail(14)
    mean_sleep = float(recent["sleep_hours"].dropna().mean()) if recent["sleep_hours"].dropna().any() else None
    mean_steps = float(recent["steps"].dropna().mean()) if recent["steps"].dropna().any() else None

    data = {
        "trainDays": days_collected,
        "positiveCount": unhealthy_count,
        "modelType": model_type,
        "valAuc": round(val_auc, 4) if val_auc is not None else None,
        "valPrAuc": round(val_pr_auc, 4) if val_pr_auc is not None else None,
        "brierScore": round(brier_score, 4) if brier_score is not None else None,
        "cvPrAucMean": round(cv_pr_auc_mean, 4) if cv_pr_auc_mean is not None else None,
        "cvPrAucStd": round(cv_pr_auc_std, 4) if cv_pr_auc_std is not None else None,
        "cvFolds": cv_folds,
        "missingRate": round(recent_missing_rate, 3),
        "moodMean14": round(mood_mean_14, 2) if mood_mean_14 is not None else None,
        "unhealthyThreshold": round(unhealthy_threshold, 2) if unhealthy_threshold is not None else None,
        "executedAt": firestore.SERVER_TIMESTAMP,
    }
    if mean_sleep is not None:
        data["meanSleep"] = round(mean_sleep, 1)
    if mean_steps is not None:
        data["meanSteps"] = round(mean_steps, 0)

    try:
        log_ref.set(data)
    except Exception:
        logger.warning("Failed to save batch log for user %s", uid)


if __name__ == "__main__":
    run_batch()
