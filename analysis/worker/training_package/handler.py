from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.training_package.repository import TrainingRepository

logger = logging.getLogger(__name__)


def run_plan_generation(
    conn: psycopg.Connection,
    training_plan_id: str,
    *,
    extension: bool = False,
) -> dict[str, Any]:
    repo = TrainingRepository(conn)

    with conn.transaction():
        assignments_created = repo.generate_plan_assignments(
            training_plan_id,
            extension=extension,
        )

    summary = {
        "training_plan_id": training_plan_id,
        "assignments_created": assignments_created,
        "extension": extension,
    }
    logger.info("Training plan generation complete summary=%s", summary)
    return summary
