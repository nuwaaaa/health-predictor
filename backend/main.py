"""Cloud Run HTTP エントリーポイント

Cloud Scheduler から HTTP POST で起動される。
03:30 JST に毎日バッチ実行。
"""

import logging
import os

from flask import Flask, jsonify

from pipeline import run_batch

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@app.route("/run", methods=["POST"])
def run():
    """バッチ実行エンドポイント"""
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
