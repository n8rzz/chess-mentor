from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

import psycopg

from worker.progress_package.constants import (
    SNAPSHOT_KIND_PERFORMANCE,
    SNAPSHOT_KIND_RATING,
    SNAPSHOT_KIND_TRAINING,
    SNAPSHOT_KIND_WEAKNESS,
    TIME_CLASS,
)
from worker.progress_package.repository import ProgressRepository

logger = logging.getLogger(__name__)


def run_snapshot_update(conn: psycopg.Connection, user_id: str) -> dict[str, Any]:
    repo = ProgressRepository(conn)
    snapshot_at = datetime.now(timezone.utc)
    snapshot_ids: list[str] = []
    kinds: list[str] = []

    with conn.transaction():
        for rating_row in repo.load_latest_ratings_by_time_class(user_id):
            snapshot_ids.append(
                repo.insert_snapshot(
                    user_id=user_id,
                    snapshot_at=snapshot_at,
                    kind=SNAPSHOT_KIND_RATING,
                    time_class=rating_row["time_class"],
                    rating=rating_row["rating"],
                )
            )
            kinds.append(SNAPSHOT_KIND_RATING)

        performance = repo.load_performance_metrics(user_id)
        if performance["games_analyzed_count"] > 0:
            snapshot_ids.append(
                repo.insert_snapshot(
                    user_id=user_id,
                    snapshot_at=snapshot_at,
                    kind=SNAPSHOT_KIND_PERFORMANCE,
                    time_class=TIME_CLASS["unknown"],
                    blunders_per_game=performance["blunders_per_game"],
                    average_centipawn_loss=performance["average_centipawn_loss"],
                    games_analyzed_count=performance["games_analyzed_count"],
                )
            )
            kinds.append(SNAPSHOT_KIND_PERFORMANCE)

        for cycle in repo.load_tracked_weakness_cycles(user_id):
            snapshot_ids.append(
                repo.insert_snapshot(
                    user_id=user_id,
                    snapshot_at=snapshot_at,
                    kind=SNAPSHOT_KIND_WEAKNESS,
                    weakness_cycle_id=cycle["id"],
                    weakness_frequency=cycle["weakness_frequency"],
                    weakness_severity=float(cycle["current_severity"])
                    if cycle["current_severity"] is not None
                    else None,
                    metadata={"current_occurrences": cycle["current_occurrences"]},
                )
            )
            kinds.append(SNAPSHOT_KIND_WEAKNESS)

        for plan in repo.load_current_training_plans(user_id):
            metadata: dict[str, Any] = {
                "plan_progress_percentage": plan["plan_progress_percentage"],
            }
            if plan["training_completion_percentage"] is not None:
                metadata["training_completion_percentage"] = plan["training_completion_percentage"]

            snapshot_ids.append(
                repo.insert_snapshot(
                    user_id=user_id,
                    snapshot_at=snapshot_at,
                    kind=SNAPSHOT_KIND_TRAINING,
                    training_plan_id=plan["id"],
                    weakness_cycle_id=plan["weakness_cycle_id"],
                    metadata=metadata,
                )
            )
            kinds.append(SNAPSHOT_KIND_TRAINING)

    summary = {
        "user_id": user_id,
        "snapshots_created": len(snapshot_ids),
        "kinds": kinds,
        "snapshot_ids": snapshot_ids,
    }
    logger.info("Progress snapshots complete user_id=%s summary=%s", user_id, summary)
    return summary
