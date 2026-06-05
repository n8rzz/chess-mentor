from __future__ import annotations

import logging
from typing import Any, Callable

from worker.jobs import SystemJobRow

logger = logging.getLogger(__name__)

Handler = Callable[[SystemJobRow], dict[str, Any]]


def _stub_handler(job: SystemJobRow) -> dict[str, Any]:
    logger.info("Stub handler for job_type=%s job_id=%s", job.job_type_key, job.id)
    return {"stub": True, "job_type": job.job_type_key}


HANDLERS: dict[str, Handler] = {
    "import_games": _stub_handler,
    "analyze_game": _stub_handler,
    "classify_weaknesses": _stub_handler,
    "generate_training_plan": _stub_handler,
    "update_progress_snapshots": _stub_handler,
}


def dispatch(job: SystemJobRow) -> dict[str, Any]:
    handler = HANDLERS.get(job.job_type_key)
    if handler is None:
        raise ValueError(f"no handler for job_type={job.job_type_key}")
    return handler(job)
