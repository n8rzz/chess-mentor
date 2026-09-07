from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.metrics_package.repository import refresh_user_period_metrics

logger = logging.getLogger(__name__)


def run_period_metrics_refresh(conn: psycopg.Connection, user_id: str) -> dict[str, Any]:
    with conn.transaction():
        summary = refresh_user_period_metrics(conn, user_id)
    logger.info("Review period metrics refresh complete summary=%s", summary)
    return summary
