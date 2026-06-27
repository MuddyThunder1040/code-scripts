from contextlib import asynccontextmanager
from decimal import Decimal
from typing import List

import yfinance as yf
from fastapi import FastAPI, HTTPException, Query

from app.config import settings
from app.db import get_session
from app.models import IngestResponse, NodeInfo, StockPrice


@asynccontextmanager
async def lifespan(app: FastAPI):
    get_session()
    yield


app = FastAPI(title="Stock Market API", version="1.0.0", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok", "cassandra": settings.cassandra_hosts}


@app.post("/ingest/{ticker}", response_model=IngestResponse)
def ingest(ticker: str, period: str = "1mo"):
    df = yf.Ticker(ticker).history(period=period)
    if df.empty:
        raise HTTPException(404, f"No data found for ticker '{ticker}'")

    session = get_session()
    stmt = session.prepare("""
        INSERT INTO market_data.stock_prices (ticker, date, ts, open, high, low, close, volume)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """)

    count = 0
    for ts, row in df.iterrows():
        session.execute(stmt, (
            ticker.upper(),
            ts.date(),
            ts.to_pydatetime(),
            Decimal(str(round(row["Open"],  4))),
            Decimal(str(round(row["High"],  4))),
            Decimal(str(round(row["Low"],   4))),
            Decimal(str(round(row["Close"], 4))),
            int(row["Volume"]),
        ))
        count += 1

    return IngestResponse(ticker=ticker.upper(), rows_inserted=count, period=period)


@app.get("/prices/{ticker}", response_model=List[StockPrice])
def get_prices(ticker: str, limit: int = Query(100, le=1000)):
    session = get_session()
    # ponytail: ALLOW FILTERING is fine for a homelab ops app on a 3-node cluster.
    rows = session.execute(
        "SELECT * FROM market_data.stock_prices WHERE ticker = %s LIMIT %s ALLOW FILTERING",
        (ticker.upper(), limit),
    )
    result = [
        StockPrice(ticker=r.ticker, date=r.date, ts=r.ts,
                   open=r.open, high=r.high, low=r.low, close=r.close, volume=r.volume)
        for r in rows
    ]
    if not result:
        raise HTTPException(404, f"No prices for '{ticker}'")
    return result


@app.get("/prices/{ticker}/latest", response_model=StockPrice)
def get_latest(ticker: str):
    return get_prices(ticker, limit=1)[0]


@app.get("/cassandra/nodes", response_model=List[NodeInfo])
def cassandra_nodes():
    session = get_session()
    local = session.execute(
        "SELECT rpc_address, data_center, rack, release_version FROM system.local"
    ).one()
    nodes = [NodeInfo(
        address=str(local.rpc_address),
        dc=local.data_center,
        rack=local.rack,
        version=local.release_version,
        status="UP",
    )]
    peers = session.execute(
        "SELECT peer, data_center, rack, release_version FROM system.peers"
    )
    for p in peers:
        nodes.append(NodeInfo(
            address=str(p.peer),
            dc=p.data_center,
            rack=p.rack,
            version=p.release_version,
            status="UP",
        ))
    return nodes


@app.get("/cassandra/keyspaces")
def cassandra_keyspaces():
    session = get_session()
    rows = session.execute(
        "SELECT keyspace_name FROM system_schema.keyspaces"
    )
    return {"keyspaces": [r.keyspace_name for r in rows]}


@app.get("/cassandra/tables")
def cassandra_tables(keyspace: str = "market_data"):
    session = get_session()
    rows = session.execute(
        "SELECT table_name FROM system_schema.tables WHERE keyspace_name = %s",
        (keyspace,),
    )
    return {"keyspace": keyspace, "tables": [r.table_name for r in rows]}
