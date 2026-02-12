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
        mood = data.get("moodScore")
        if mood is None:
            continue

        sleep_data = data.get("sleep", {})
        rows.append(
            {
                "date_key": doc.id,
                "moodScore": mood,
                "sleep_hours": sleep_data.get("durationHours"),
                "steps": data.get("steps"),
                "stress": data.get("stress"),
            }
        )

    if not rows:
        logger.info("No mood data for user %s", uid)
        return

    df = pd.DataFrame(rows).sort_values("date_key").reset_index(drop=True)
    days_collected = len(df)

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

    model_type = today_result["model_type"]
    model_version = f"{model_type}_v1"

    # 改善アドバイス生成
    advices = generate_advice(df, today_result["probability"])

    # 特徴量寄与度TOP3
    contributions = today_result.get("contributions", [])

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
    )

    logger.info(
        "User %s: pToday=%.3f, p3d=%s, model=%s, confidence=%s, auc=%s, pr_auc=%s",
        uid,
        today_result["probability"] or 0,
        f"{p3d:.3f}" if p3d is not None else "N/A",
        model_type,
        confidence_level,
        today_result["auc"],
        today_result["pr_auc"],
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
):
    """model_status を更新"""
    status_ref = (
        db.collection("users")
        .document(uid)
        .collection("model_status")
        .document("current")
    )

    status_ref.set(
        {
            "daysCollected": days_collected,
            "daysRequired": config.MIN_DAYS_TODAY,
            "ready": ready,
            "unhealthyCount": unhealthy_count,
            "recentMissingRate": round(recent_missing_rate, 3),
            "modelType": model_type,
            "confidenceLevel": confidence_level,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


if __name__ == "__main__":
    run_batch()
