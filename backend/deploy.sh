#!/bin/bash
# Cloud Run デプロイ + Cloud Scheduler 設定スクリプト
#
# 前提: gcloud CLI がインストール済み、プロジェクトが設定済み
#
# 使い方:
#   chmod +x deploy.sh
#   ./deploy.sh <GCP_PROJECT_ID> <REGION>
#
# 例:
#   ./deploy.sh my-health-app asia-northeast1

set -euo pipefail

PROJECT_ID="${1:?Usage: ./deploy.sh <PROJECT_ID> <REGION>}"
REGION="${2:-asia-northeast1}"
SERVICE_NAME="health-predictor-batch"

echo "=== Cloud Run デプロイ ==="
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Service: $SERVICE_NAME"
echo ""

# Cloud Run にデプロイ
gcloud run deploy "$SERVICE_NAME" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --source . \
  --no-allow-unauthenticated \
  --memory 512Mi \
  --timeout 300 \
  --max-instances 1

# サービスURL取得
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --format "value(status.url)")

echo ""
echo "=== Cloud Scheduler 設定 ==="
echo "Service URL: $SERVICE_URL"

# サービスアカウント作成（初回のみ）
SA_NAME="scheduler-invoker"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT_ID" &>/dev/null; then
  echo "Creating service account: $SA_EMAIL"
  gcloud iam service-accounts create "$SA_NAME" \
    --project "$PROJECT_ID" \
    --display-name "Cloud Scheduler Invoker"

  gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
    --project "$PROJECT_ID" \
    --region "$REGION" \
    --member "serviceAccount:$SA_EMAIL" \
    --role "roles/run.invoker"
fi

# Cloud Scheduler ジョブ作成（毎日 03:30 JST）
JOB_NAME="health-predictor-daily-batch"

if gcloud scheduler jobs describe "$JOB_NAME" --project "$PROJECT_ID" --location "$REGION" &>/dev/null; then
  echo "Updating existing scheduler job..."
  gcloud scheduler jobs update http "$JOB_NAME" \
    --project "$PROJECT_ID" \
    --location "$REGION" \
    --schedule "30 3 * * *" \
    --time-zone "Asia/Tokyo" \
    --uri "${SERVICE_URL}/run" \
    --http-method POST \
    --oidc-service-account-email "$SA_EMAIL"
else
  echo "Creating scheduler job..."
  gcloud scheduler jobs create http "$JOB_NAME" \
    --project "$PROJECT_ID" \
    --location "$REGION" \
    --schedule "30 3 * * *" \
    --time-zone "Asia/Tokyo" \
    --uri "${SERVICE_URL}/run" \
    --http-method POST \
    --oidc-service-account-email "$SA_EMAIL"
fi

echo ""
echo "=== 完了 ==="
echo "Cloud Run:       $SERVICE_URL"
echo "Scheduler:       毎日 03:30 JST に POST ${SERVICE_URL}/run"
echo ""
echo "手動テスト実行:"
echo "  gcloud scheduler jobs run $JOB_NAME --project $PROJECT_ID --location $REGION"
