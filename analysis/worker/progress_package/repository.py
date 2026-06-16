from __future__ import annotations

import json
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any

import psycopg

from worker.import_package.ids import new_ulid
from worker.progress_package.calculators import (
    compute_plan_progress_percentage,
    compute_training_completion_percentage,
    compute_weakness_frequency,
)
from worker.progress_package.constants import (
    ANALYSIS_RUN_SUCCEEDED,
    ASSIGNMENT_STATUS_COMPLETED,
    CYCLE_STATUS_TRACKED,
    JOB_STATUS_CLAIMED,
    JOB_STATUS_PENDING,
    JOB_STATUS_PROCESSING,
    JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS,
    PLAN_STATUS_CURRENT,
    RATING_TIME_CLASSES,
    SNAPSHOT_KIND_PERFORMANCE,
    SNAPSHOT_KIND_RATING,
    SNAPSHOT_KIND_TRAINING,
    SNAPSHOT_KIND_WEAKNESS,
    TIME_CLASS,
)
from worker.eval_package.constants import CLASSIFICATION


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ProgressRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def enqueue_snapshots_if_needed(self, user_id: str) -> bool:
        existing = self._conn.execute(
            """
            SELECT 1
            FROM system_jobs
            WHERE user_id = %s
              AND job_type = %s
              AND status IN (%s, %s, %s)
            LIMIT 1
            """,
            (
                user_id,
                JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS,
                JOB_STATUS_PENDING,
                JOB_STATUS_CLAIMED,
                JOB_STATUS_PROCESSING,
            ),
        ).fetchone()
        if existing is not None:
            return False

        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO system_jobs (
              id, user_id, job_type, status, payload,
              attempts_count, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s, %s)
            """,
            (
                new_ulid(),
                user_id,
                JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS,
                JOB_STATUS_PENDING,
                json.dumps({}),
                0,
                now,
                now,
            ),
        )
        return True

    def load_latest_ratings_by_time_class(self, user_id: str) -> list[dict[str, Any]]:
        rows = self._conn.execute(
            """
            SELECT DISTINCT ON (time_class) time_class, user_rating
            FROM games
            WHERE user_id = %s
              AND user_rating IS NOT NULL
              AND time_class = ANY(%s)
            ORDER BY time_class, played_at DESC
            """,
            (user_id, list(RATING_TIME_CLASSES)),
        ).fetchall()
        return [{"time_class": row[0], "rating": row[1]} for row in rows]

    def load_performance_metrics(self, user_id: str) -> dict[str, Any]:
        analyzed_row = self._conn.execute(
            """
            SELECT COUNT(DISTINCT g.id)
            FROM games g
            INNER JOIN analysis_runs ar ON ar.game_id = g.id
            WHERE g.user_id = %s
              AND ar.status = %s
            """,
            (user_id, ANALYSIS_RUN_SUCCEEDED),
        ).fetchone()
        analyzed_game_count = int(analyzed_row[0]) if analyzed_row else 0

        blunder_row = self._conn.execute(
            """
            SELECT COUNT(*)
            FROM move_evaluations me
            INNER JOIN analysis_runs ar ON ar.id = me.analysis_run_id
            WHERE ar.user_id = %s
              AND ar.status = %s
              AND me.classification = %s
            """,
            (user_id, ANALYSIS_RUN_SUCCEEDED, CLASSIFICATION["blunder"]),
        ).fetchone()
        blunder_count = int(blunder_row[0]) if blunder_row else 0

        cpl_row = self._conn.execute(
            """
            SELECT AVG(me.centipawn_loss)
            FROM move_evaluations me
            INNER JOIN analysis_runs ar ON ar.id = me.analysis_run_id
            WHERE ar.user_id = %s
              AND ar.status = %s
            """,
            (user_id, ANALYSIS_RUN_SUCCEEDED),
        ).fetchone()
        average_centipawn_loss = cpl_row[0] if cpl_row and cpl_row[0] is not None else None

        blunders_per_game = None
        if analyzed_game_count > 0:
            blunders_per_game = Decimal(blunder_count) / Decimal(analyzed_game_count)

        return {
            "games_analyzed_count": analyzed_game_count,
            "blunder_count": blunder_count,
            "blunders_per_game": blunders_per_game,
            "average_centipawn_loss": average_centipawn_loss,
        }

    def load_tracked_weakness_cycles(self, user_id: str) -> list[dict[str, Any]]:
        rows = self._conn.execute(
            """
            SELECT id, current_occurrences, current_severity, detection_window_games, metadata
            FROM weakness_cycles
            WHERE user_id = %s
              AND status = ANY(%s)
            ORDER BY current_severity DESC NULLS LAST, current_occurrences DESC
            """,
            (user_id, list(CYCLE_STATUS_TRACKED.values())),
        ).fetchall()
        cycles = []
        for row in rows:
            metadata = row[4] or {}
            cycles.append(
                {
                    "id": row[0],
                    "current_occurrences": row[1],
                    "current_severity": row[2],
                    "detection_window_games": row[3],
                    "metadata": metadata,
                    "weakness_frequency": compute_weakness_frequency(row[1], row[3], metadata),
                }
            )
        return cycles

    def load_current_training_plans(self, user_id: str) -> list[dict[str, Any]]:
        rows = self._conn.execute(
            """
            SELECT id, weakness_cycle_id, baseline_occurrences, current_occurrences, progress_percentage
            FROM training_plans
            WHERE user_id = %s
              AND status = ANY(%s)
            ORDER BY updated_at DESC
            """,
            (user_id, list(PLAN_STATUS_CURRENT.values())),
        ).fetchall()

        today = date.today()
        plans = []
        for row in rows:
            plan_id = row[0]
            counts = self._conn.execute(
                """
                SELECT
                  COUNT(*) FILTER (WHERE due_on <= %s) AS due_through_today,
                  COUNT(*) FILTER (
                    WHERE due_on <= %s AND status = %s
                  ) AS completed_through_today
                FROM training_assignments
                WHERE training_plan_id = %s
                """,
                (today, today, ASSIGNMENT_STATUS_COMPLETED, plan_id),
            ).fetchone()
            due_through_today = int(counts[0]) if counts else 0
            completed_through_today = int(counts[1]) if counts else 0
            baseline = int(row[2])
            current = int(row[3])
            plan_progress = row[4]
            if plan_progress is None:
                plan_progress = compute_plan_progress_percentage(baseline, current)

            plans.append(
                {
                    "id": plan_id,
                    "weakness_cycle_id": row[1],
                    "plan_progress_percentage": float(plan_progress),
                    "training_completion_percentage": compute_training_completion_percentage(
                        completed_through_today,
                        due_through_today,
                    ),
                }
            )
        return plans

    def insert_snapshot(
        self,
        *,
        user_id: str,
        snapshot_at: datetime,
        kind: str,
        time_class: int = TIME_CLASS["unknown"],
        rating: int | None = None,
        weakness_cycle_id: str | None = None,
        training_plan_id: str | None = None,
        weakness_frequency: float | None = None,
        weakness_severity: float | None = None,
        blunders_per_game: Decimal | None = None,
        average_centipawn_loss: Decimal | None = None,
        games_analyzed_count: int = 0,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        snapshot_id = new_ulid()
        payload = {"kind": kind, **(metadata or {})}
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO progress_snapshots (
              id, user_id, training_plan_id, weakness_cycle_id,
              time_class, rating, weakness_frequency, weakness_severity,
              blunders_per_game, average_centipawn_loss, games_analyzed_count,
              snapshot_at, metadata, created_at, updated_at
            ) VALUES (
              %s, %s, %s, %s,
              %s, %s, %s, %s,
              %s, %s, %s,
              %s, %s::jsonb, %s, %s
            )
            """,
            (
                snapshot_id,
                user_id,
                training_plan_id,
                weakness_cycle_id,
                time_class,
                rating,
                weakness_frequency,
                weakness_severity,
                blunders_per_game,
                average_centipawn_loss,
                games_analyzed_count,
                snapshot_at,
                json.dumps(payload),
                now,
                now,
            ),
        )
        return snapshot_id
