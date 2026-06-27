from cassandra.cluster import Cluster
from app.config import settings

_session = None


def get_session():
    global _session
    if _session is None:
        cluster = Cluster(
            contact_points=settings.cassandra_hosts.split(","),
            port=settings.cassandra_port,
            # ponytail: only seed (100.64.213.62) has CQL port exposed from Dell.
            # Driver marks unreachable peers DOWN and uses only the seed — fine for homelab.
        )
        _session = cluster.connect()
        _bootstrap(_session)
    return _session


def _bootstrap(session):
    session.execute("""
        CREATE KEYSPACE IF NOT EXISTS market_data
        WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 2}
    """)
    session.execute("""
        CREATE TABLE IF NOT EXISTS market_data.stock_prices (
            ticker  TEXT,
            date    DATE,
            ts      TIMESTAMP,
            open    DECIMAL,
            high    DECIMAL,
            low     DECIMAL,
            close   DECIMAL,
            volume  BIGINT,
            PRIMARY KEY ((ticker, date), ts)
        ) WITH CLUSTERING ORDER BY (ts DESC)
    """)
