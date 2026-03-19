"""Cloud Run HTTP エントリーポイント

Cloud Scheduler から HTTP POST で起動される。
03:30 JST に毎日バッチ実行。
"""

import logging
import os

from flask import Flask, jsonify, request

from pipeline import run_batch

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _verify_oidc_token() -> bool:
    """Cloud Scheduler の OIDC トークンを検証する。

    SKIP_AUTH=1 が設定されている場合はスキップ（ローカル開発用）。
    """
    if os.environ.get("SKIP_AUTH") == "1":
        return True

    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return False

    token = auth_header.split("Bearer ", 1)[1]
    try:
        import google.auth.transport.requests
        import google.oauth2.id_token

        google.oauth2.id_token.verify_oauth2_token(
            token, google.auth.transport.requests.Request()
        )
        return True
    except Exception:
        logger.warning("OIDC token verification failed")
        return False


@app.route("/run", methods=["POST"])
def run():
    """バッチ実行エンドポイント（OIDC認証必須）"""
    if not _verify_oidc_token():
        return jsonify({"status": "error", "message": "Unauthorized"}), 401

    try:
        run_batch()
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        logger.exception("Batch failed")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    """ヘルスチェック"""
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
