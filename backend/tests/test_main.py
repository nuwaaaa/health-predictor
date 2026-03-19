"""main.py のエンドポイント認証テスト"""

import os
import sys
from types import ModuleType
from unittest.mock import patch, MagicMock

import pytest

# pipeline モジュールが google.cloud.firestore に依存するため、
# テスト時はモックモジュールで差し替える
_mock_google = ModuleType("google")
_mock_google.cloud = ModuleType("google.cloud")  # type: ignore[attr-defined]
_mock_google.cloud.firestore = MagicMock()  # type: ignore[attr-defined]
sys.modules.setdefault("google", _mock_google)
sys.modules.setdefault("google.cloud", _mock_google.cloud)  # type: ignore[arg-type]
sys.modules.setdefault("google.cloud.firestore", _mock_google.cloud.firestore)  # type: ignore[arg-type]

# pipeline をモックして main をインポート可能にする
_mock_pipeline = ModuleType("pipeline")
_mock_pipeline.run_batch = MagicMock()  # type: ignore[attr-defined]
sys.modules.setdefault("pipeline", _mock_pipeline)

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from main import app  # noqa: E402


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


class TestRunEndpointAuth:
    """OIDC トークン検証のテスト"""

    def test_no_auth_header_returns_401(self, client):
        """Authorization ヘッダーなしは 401"""
        with patch.dict(os.environ, {}, clear=False):
            # SKIP_AUTH が設定されていないことを保証
            os.environ.pop("SKIP_AUTH", None)
            resp = client.post("/run")
        assert resp.status_code == 401
        assert resp.get_json()["message"] == "Unauthorized"

    def test_invalid_bearer_returns_401(self, client):
        """不正な Bearer トークンは 401"""
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SKIP_AUTH", None)
            resp = client.post("/run", headers={"Authorization": "Bearer invalid"})
        assert resp.status_code == 401

    def test_non_bearer_auth_returns_401(self, client):
        """Basic 認証等は 401"""
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SKIP_AUTH", None)
            resp = client.post("/run", headers={"Authorization": "Basic abc123"})
        assert resp.status_code == 401

    def test_skip_auth_allows_request(self, client):
        """SKIP_AUTH=1 で認証スキップ"""
        with patch.dict(os.environ, {"SKIP_AUTH": "1"}):
            with patch("main.run_batch") as mock_batch:
                mock_batch.return_value = None
                resp = client.post("/run")
        assert resp.status_code == 200
        mock_batch.assert_called_once()


class TestHealthEndpoint:
    """ヘルスチェックは認証不要"""

    def test_health_returns_200(self, client):
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.get_json()["status"] == "healthy"
