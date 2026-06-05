from __future__ import annotations

import logging
import os
import time
from pathlib import Path

import psycopg

from worker.config import Config, load_config
from worker.handlers import dispatch
from worker.jobs import claim_next_job, mark_failed, mark_succeeded

logger = logging.getLogger(__name__)


def verify_stockfish(config: Config) -> None:
    path = Path(config.stockfish_path)
    if not path.is_file():
        raise FileNotFoundError(f"Stockfish binary not found at {config.stockfish_path}")


def verify_database(config: Config) -> None:
    with psycopg.connect(config.database_url) as conn:
        conn.execute("SELECT 1")


def poll_once(config: Config) -> None:
    with psycopg.connect(config.database_url) as conn:
        job = claim_next_job(conn, config.worker_id)
        if job is None:
            logger.debug("No pending system jobs (worker=%s)", config.worker_id)
            return

        started = time.monotonic()
        logger.info(
            "Processing system job id=%s type=%s worker=%s",
            job.id,
            job.job_type_key,
            config.worker_id,
        )

        try:
            result = dispatch(job)
            mark_succeeded(conn, job.id, result)
            elapsed = time.monotonic() - started
            logger.info("System job id=%s succeeded in %.2fs", job.id, elapsed)
        except Exception as exc:
            mark_failed(
                conn,
                job.id,
                str(exc),
                details={"code": "handler_error", "job_type": job.job_type_key},
            )
            elapsed = time.monotonic() - started
            logger.exception("System job id=%s failed in %.2fs", job.id, elapsed)


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
