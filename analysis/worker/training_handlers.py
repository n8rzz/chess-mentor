from __future__ import annotations

import logging
from typing import Any

from worker.jobs import SystemJobRow
from worker.training_package.handler import run_plan_generation

logger = logging.getLogger(__name__)


def generate_training_plan_handler(job: SystemJobRow) -> dict[str, Any]:
    training_plan_id = job.payload.get("training_plan_id")
    if not training_plan_id:
        raise ValueError("training_plan_id is required")

    extension = bool(job.payload.get("extension"))

    from worker.config import load_config
    import psycopg

    config = load_config()
    with psycopg.connect(config.database_url) as conn:
        return run_plan_generation(conn, training_plan_id, extension=extension)
