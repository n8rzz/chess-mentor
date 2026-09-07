from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.config import load_config
from worker.jobs import SystemJobRow
from worker.progress_package.repository import ProgressRepository
from worker.weakness_package.handler import run_classification

logger = logging.getLogger(__name__)


def classify_patterns_handler(job: SystemJobRow) -> dict[str, Any]:
    user_id = job.payload.get("user_id") or job.user_id
    if not user_id:
        raise ValueError("user_id is required")

    config = load_config()
    with psycopg.connect(config.database_url) as conn:
        summary = run_classification(conn, user_id)
        ProgressRepository(conn).enqueue_snapshots_if_needed(user_id)
        conn.commit()
        return summary
