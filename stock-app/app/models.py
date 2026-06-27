from pydantic import BaseModel
from datetime import datetime, date
from decimal import Decimal


class StockPrice(BaseModel):
    ticker: str
    date: date
    ts: datetime
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal
    volume: int


class IngestResponse(BaseModel):
    ticker: str
    rows_inserted: int
    period: str


class NodeInfo(BaseModel):
    address: str
    dc: str
    rack: str
    version: str
    status: str
