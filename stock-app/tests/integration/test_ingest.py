"""
Integration tests — run against live dev deployment.
Requires APP_URL env var (default: http://localhost:8001).
"""
import os
import pytest
import httpx

BASE = os.getenv("APP_URL", "http://localhost:8001")


def test_health():
    r = httpx.get(f"{BASE}/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_cassandra_nodes():
    r = httpx.get(f"{BASE}/cassandra/nodes")
    assert r.status_code == 200
    nodes = r.json()
    assert len(nodes) >= 1
    assert all("dc" in n for n in nodes)


def test_cassandra_keyspaces():
    r = httpx.get(f"{BASE}/cassandra/keyspaces")
    assert r.status_code == 200
    assert "market_data" in r.json()["keyspaces"]


def test_ingest_and_query():
    ticker = "MSFT"

    r = httpx.post(f"{BASE}/ingest/{ticker}?period=5d", timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert body["ticker"] == ticker
    assert body["rows_inserted"] >= 1

    r = httpx.get(f"{BASE}/prices/{ticker}")
    assert r.status_code == 200
    prices = r.json()
    assert len(prices) >= 1
    assert prices[0]["ticker"] == ticker


def test_latest_price():
    r = httpx.get(f"{BASE}/prices/MSFT/latest")
    assert r.status_code == 200
    p = r.json()
    assert p["ticker"] == "MSFT"
    assert float(p["close"]) > 0


def test_unknown_ticker_404():
    r = httpx.get(f"{BASE}/prices/ZZZNOTREAL")
    assert r.status_code == 404
