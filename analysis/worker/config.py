from __future__ import annotations

import os
import socket
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env.worker")


@dataclass(frozen=True)
class Config:
    database_host: str
    database_port: int
    database_username: str
    database_password: str
    database_name: str
    redis_url: str
    stockfish_path: str
    worker_id: str
    poll_interval_seconds: float

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.database_username}:{self.database_password}"
            f"@{self.database_host}:{self.database_port}/{self.database_name}"
        )


def load_config() -> Config:
    return Config(
        database_host=os.environ["DATABASE_HOST"],
        database_port=int(os.environ.get("DATABASE_PORT", "5432")),
        database_username=os.environ["DATABASE_USERNAME"],
        database_password=os.environ["DATABASE_PASSWORD"],
        database_name=os.environ["DATABASE_NAME"],
        redis_url=os.environ["REDIS_URL"],
        stockfish_path=os.environ["STOCKFISH_PATH"],
        worker_id=os.environ.get("WORKER_ID") or socket.gethostname(),
        poll_interval_seconds=float(os.environ.get("WORKER_POLL_INTERVAL_SECONDS", "2")),
    )
