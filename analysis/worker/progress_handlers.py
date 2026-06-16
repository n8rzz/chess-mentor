from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.config import load_config
from worker.jobs import SystemJobRow
from worker.progress_package.handler import run_snapshot_update

logger = logging.getLogger(__name__)


def update_progress_snapshots_handler(job: SystemJobRow) -> dict[str, Any]:
    user_id = job.payload.get("user_id") or job.user_id
    if not user_id:
        raise ValueError("user_id is required")

    config = load_config()
    with psycopg.connect(config.database_url) as conn:
        return run_snapshot_update(conn, user_id)
