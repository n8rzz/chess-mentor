from __future__ import annotations

import logging
from typing import Any, Callable

from worker.analyze_handlers import analyze_game_handler
from worker.classify_handlers import classify_weaknesses_handler
from worker.import_handlers import import_games_handler
from worker.training_handlers import generate_training_plan_handler
from worker.jobs import SystemJobRow

logger = logging.getLogger(__name__)

Handler = Callable[[SystemJobRow], dict[str, Any]]


def _stub_handler(job: SystemJobRow) -> dict[str, Any]:
    logger.info("Stub handler for job_type=%s job_id=%s", job.job_type_key, job.id)
    return {"stub": True, "job_type": job.job_type_key}


HANDLERS: dict[str, Handler] = {
    "import_games": import_games_handler,
    "analyze_game": analyze_game_handler,
    "classify_weaknesses": classify_weaknesses_handler,
    "generate_training_plan": generate_training_plan_handler,
    "update_progress_snapshots": _stub_handler,
}


def dispatch(job: SystemJobRow) -> dict[str, Any]:
    handler = HANDLERS.get(job.job_type_key)
    if handler is None:
        raise ValueError(f"no handler for job_type={job.job_type_key}")
    return handler(job)
