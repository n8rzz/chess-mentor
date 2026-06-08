from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.config import load_config
from worker.eval_package.handler import run_analysis
from worker.jobs import SystemJobRow

logger = logging.getLogger(__name__)


def analyze_game_handler(job: SystemJobRow) -> dict[str, Any]:
    analysis_run_id = job.payload.get("analysis_run_id")
    game_id = job.payload.get("game_id")
    if not analysis_run_id:
        raise ValueError("analysis_run_id is required")
    if not game_id:
        raise ValueError("game_id is required")

    config = load_config()
    with psycopg.connect(config.database_url) as conn:
        return run_analysis(conn, analysis_run_id, game_id)
