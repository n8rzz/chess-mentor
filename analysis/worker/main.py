from __future__ import annotations

import logging
import os
import time
from pathlib import Path

import psycopg

from worker.config import Config, load_config

logger = logging.getLogger(__name__)


def verify_stockfish(config: Config) -> None:
    path = Path(config.stockfish_path)
    if not path.is_file():
        raise FileNotFoundError(f"Stockfish binary not found at {config.stockfish_path}")


def verify_database(config: Config) -> None:
    with psycopg.connect(config.database_url) as conn:
        conn.execute("SELECT 1")


def poll_once(config: Config) -> None:
    # Milestone 0 skeleton: claim SystemJob rows once the table exists (Milestone 0/2).
    logger.debug("Polling for pending system jobs (worker=%s)", config.worker_id)


def run_worker(config: Config) -> None:
    verify_stockfish(config)
    verify_database(config)
    logger.info(
        "Worker started (id=%s, stockfish=%s, db=%s)",
        config.worker_id,
        config.stockfish_path,
        config.database_host,
    )

    while True:
        poll_once(config)
        time.sleep(config.poll_interval_seconds)


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    run_worker(load_config())


if __name__ == "__main__":
    main()
