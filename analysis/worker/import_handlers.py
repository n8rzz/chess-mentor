from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.config import load_config
from worker.import_package.handler import run_import
from worker.jobs import SystemJobRow

logger = logging.getLogger(__name__)


def import_games_handler(job: SystemJobRow) -> dict[str, Any]:
    import_batch_id = job.payload.get("import_batch_id")
    if not import_batch_id:
        raise ValueError("import_batch_id is required")

    config = load_config()
    with psycopg.connect(config.database_url) as conn:
        return run_import(conn, import_batch_id)
