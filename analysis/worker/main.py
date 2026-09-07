from __future__ import annotations

import logging
import os
import threading
import time
from pathlib import Path

import psycopg

from worker.config import Config, load_config
from worker.handlers import dispatch
from worker.jobs import claim_next_job, heartbeat_job, mark_failed, mark_succeeded

logger = logging.getLogger(__name__)

HEARTBEAT_INTERVAL_SECONDS = float(os.environ.get("SYSTEM_JOB_HEARTBEAT_SECONDS", "30"))


def verify_stockfish(config: Config) -> None:
    path = Path(config.stockfish_path)
    if not path.is_file():
        raise FileNotFoundError(f"Stockfish binary not found at {config.stockfish_path}")


def verify_database(config: Config) -> None:
    with psycopg.connect(config.database_url) as conn:
        conn.execute("SELECT 1")


def _start_heartbeat(config: Config, job_id: str) -> tuple[threading.Event, threading.Thread]:
    stop = threading.Event()

    def _loop() -> None:
        while not stop.wait(HEARTBEAT_INTERVAL_SECONDS):
            try:
                with psycopg.connect(config.database_url) as conn:
                    alive = heartbeat_job(conn, job_id)
                    if not alive:
                        logger.warning(
                            "Heartbeat skipped; job no longer in progress id=%s",
                            job_id,
                        )
                        return
                    logger.debug("Heartbeat ok id=%s", job_id)
            except Exception:
                logger.exception("Heartbeat failed id=%s", job_id)

    thread = threading.Thread(
        target=_loop,
        name=f"system-job-heartbeat-{job_id}",
        daemon=True,
    )
    thread.start()
    return stop, thread


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

        stop_heartbeat, heartbeat_thread = _start_heartbeat(config, job.id)
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
        finally:
            stop_heartbeat.set()
            heartbeat_thread.join(timeout=HEARTBEAT_INTERVAL_SECONDS + 1)


def run_worker(config: Config) -> None:
    verify_stockfish(config)
    verify_database(config)
    logger.info(
        "Worker started (id=%s, stockfish=%s, db=%s, heartbeat=%ss)",
        config.worker_id,
        config.stockfish_path,
        config.database_host,
        HEARTBEAT_INTERVAL_SECONDS,
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
