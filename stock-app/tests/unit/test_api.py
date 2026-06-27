import pandas as pd
import pytest
from decimal import Decimal
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient


@pytest.fixture
def mock_session():
    session = MagicMock()
    session.execute.return_value = []
    return session


@pytest.fixture
def client(mock_session):
    with patch("app.db.get_session", return_value=mock_session), \
         patch("app.db._bootstrap"):
        from app.main import app
        with TestClient(app, raise_server_exceptions=True) as c:
            yield c, mock_session


def test_health(client):
    c, _ = client
    r = c.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_ingest_success(client):
    c, session = client
    mock_df = pd.DataFrame({
        "Open":   [150.0],
        "High":   [155.0],
        "Low":    [149.0],
        "Close":  [153.0],
        "Volume": [1000000],
    }, index=pd.to_datetime(["2024-01-01"], utc=True))

    with patch("app.main.yf.Ticker") as mock_ticker:
        mock_ticker.return_value.history.return_value = mock_df
        r = c.post("/ingest/AAPL")

    assert r.status_code == 200
    body = r.json()
    assert body["ticker"] == "AAPL"
    assert body["rows_inserted"] == 1


def test_ingest_unknown_ticker(client):
    c, _ = client
    with patch("app.main.yf.Ticker") as mock_ticker:
        mock_ticker.return_value.history.return_value = pd.DataFrame()
        r = c.post("/ingest/NOTREAL")
    assert r.status_code == 404


def test_get_prices_not_found(client):
    c, session = client
    session.execute.return_value = []
    r = c.get("/prices/AAPL")
    assert r.status_code == 404


def test_get_prices_returns_data(client):
    c, session = client
    row = MagicMock()
    row.ticker = "AAPL"
    row.date = __import__("datetime").date(2024, 1, 1)
    row.ts = __import__("datetime").datetime(2024, 1, 1, 0, 0)
    row.open = Decimal("150.00")
    row.high = Decimal("155.00")
    row.low  = Decimal("149.00")
    row.close = Decimal("153.00")
    row.volume = 1000000
    session.execute.return_value = [row]

    r = c.get("/prices/AAPL")
    assert r.status_code == 200
    assert r.json()[0]["ticker"] == "AAPL"


def test_cassandra_keyspaces(client):
    c, session = client
    row = MagicMock()
    row.keyspace_name = "market_data"
    session.execute.return_value = [row]

    r = c.get("/cassandra/keyspaces")
    assert r.status_code == 200
    assert "market_data" in r.json()["keyspaces"]
