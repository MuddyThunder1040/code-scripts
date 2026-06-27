from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    cassandra_hosts: str = "100.64.213.62"
    cassandra_port: int = 9042
    cassandra_keyspace: str = "market_data"
    cassandra_dc: str = "datacenter1"

    model_config = {"env_file": ".env"}


settings = Settings()
