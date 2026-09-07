from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

import psycopg

from worker.eval_package.constants import EVENT_TYPE
from worker.import_package.ids import new_ulid
from worker.metrics_package.calculators import (
    MoveMetricInput,
    aggregate_period_metrics,
    compute_game_metrics,
)
from worker.metrics_package.constants import (
    JOB_STATUS_CLAIMED,
    JOB_STATUS_PENDING,
    JOB_STATUS_PROCESSING,
    JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS,
    METRIC_FORMULA_VERSION,
    REVIEW_PERIOD_STATUS,
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _decimal_or_none(value: Any) -> Decimal | None:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


class MetricsRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def load_game_metric_inputs(self, analysis_run_id: str) -> dict[str, Any] | None:
        run = self._conn.execute(
            """
            SELECT ar.id, ar.user_id, ar.game_id, g.result, g.time_class, g.time_control
            FROM analysis_runs ar
            INNER JOIN games g ON g.id = ar.game_id
            WHERE ar.id = %s
            """,
            (analysis_run_id,),
        ).fetchone()
        if run is None:
            return None

        rows = self._conn.execute(
            """
            SELECT
              m.id, m.ply, m.phase, m.clock_before, m.clock_after,
              me.centipawn_loss, me.classification, me.critical_position,
              me.eval_before_cp, me.eval_after_cp
            FROM move_evaluations me
            INNER JOIN moves m ON m.id = me.move_id
            WHERE me.analysis_run_id = %s
              AND m.played_by_user = TRUE
            ORDER BY m.ply ASC
            """,
            (analysis_run_id,),
        ).fetchall()

        move_ids = [row[0] for row in rows]
        pressure_move_ids: set[str] = set()
        if move_ids:
            event_rows = self._conn.execute(
                """
                SELECT DISTINCT move_id
                FROM analysis_events
                WHERE analysis_run_id = %s
                  AND event_type = %s
                  AND move_id = ANY(%s)
                """,
                (analysis_run_id, EVENT_TYPE["time_pressure"], move_ids),
            ).fetchall()
            pressure_move_ids = {row[0] for row in event_rows}

        moves = [
            MoveMetricInput(
                move_id=row[0],
                ply=int(row[1]),
                phase=row[2],
                clock_before=row[3],
                clock_after=row[4],
                centipawn_loss=int(row[5]),
                classification=int(row[6]),
                critical_position=bool(row[7]),
                eval_before_cp=row[8],
                eval_after_cp=row[9],
                has_time_pressure_event=row[0] in pressure_move_ids,
            )
            for row in rows
        ]

        return {
            "analysis_run_id": run[0],
            "user_id": run[1],
            "game_id": run[2],
            "game_result": int(run[3]),
            "time_class": int(run[4]),
            "time_control": run[5],
            "moves": moves,
        }

    def upsert_game_metrics(
        self,
        *,
        user_id: str,
        game_id: str,
        analysis_run_id: str,
        metrics: dict[str, Any],
        metric_formula_version: str = METRIC_FORMULA_VERSION,
    ) -> str:
        now = _utcnow()
        existing = self._conn.execute(
            """
            SELECT id FROM game_metrics WHERE analysis_run_id = %s
            """,
            (analysis_run_id,),
        ).fetchone()
        metric_id = existing[0] if existing else new_ulid()

        fields = (
            metric_formula_version,
            _decimal_or_none(metrics.get("average_centipawn_loss")),
            int(metrics.get("user_move_count") or 0),
            int(metrics.get("inaccuracies_count") or 0),
            int(metrics.get("mistakes_count") or 0),
            int(metrics.get("blunders_count") or 0),
            json.dumps(metrics.get("phase_metrics") or {}),
            int(metrics.get("winning_positions_reached") or 0),
            int(metrics.get("winning_positions_converted") or 0),
            int(metrics.get("time_pressure_moves_count") or 0),
            int(metrics.get("time_pressure_mistakes_count") or 0),
            _decimal_or_none(metrics.get("time_pressure_error_rate")),
            int(metrics.get("fast_moves_count") or 0),
            int(metrics.get("fast_move_mistakes_count") or 0),
            _decimal_or_none(metrics.get("fast_move_error_rate")),
            int(metrics.get("critical_moves_count") or 0),
            int(metrics.get("critical_accurate_count") or 0),
            _decimal_or_none(metrics.get("critical_position_accuracy")),
            json.dumps(metrics.get("metadata") or {}),
        )

        if existing:
            self._conn.execute(
                """
                UPDATE game_metrics SET
                  metric_formula_version = %s,
                  average_centipawn_loss = %s,
                  user_move_count = %s,
                  inaccuracies_count = %s,
                  mistakes_count = %s,
                  blunders_count = %s,
                  phase_metrics = %s::jsonb,
                  winning_positions_reached = %s,
                  winning_positions_converted = %s,
                  time_pressure_moves_count = %s,
                  time_pressure_mistakes_count = %s,
                  time_pressure_error_rate = %s,
                  fast_moves_count = %s,
                  fast_move_mistakes_count = %s,
                  fast_move_error_rate = %s,
                  critical_moves_count = %s,
                  critical_accurate_count = %s,
                  critical_position_accuracy = %s,
                  metadata = %s::jsonb,
                  updated_at = %s
                WHERE id = %s
                """,
                fields + (now, metric_id),
            )
        else:
            self._conn.execute(
                """
                INSERT INTO game_metrics (
                  id, user_id, game_id, analysis_run_id, metric_formula_version,
                  average_centipawn_loss, user_move_count,
                  inaccuracies_count, mistakes_count, blunders_count,
                  phase_metrics,
                  winning_positions_reached, winning_positions_converted,
                  time_pressure_moves_count, time_pressure_mistakes_count,
                  time_pressure_error_rate,
                  fast_moves_count, fast_move_mistakes_count, fast_move_error_rate,
                  critical_moves_count, critical_accurate_count,
                  critical_position_accuracy, metadata,
                  created_at, updated_at
                ) VALUES (
                  %s, %s, %s, %s, %s,
                  %s, %s,
                  %s, %s, %s,
                  %s::jsonb,
                  %s, %s,
                  %s, %s,
                  %s,
                  %s, %s, %s,
                  %s, %s,
                  %s, %s::jsonb,
                  %s, %s
                )
                """,
                (metric_id, user_id, game_id, analysis_run_id) + fields + (now, now),
            )
        return metric_id
    def enqueue_period_refresh_if_needed(self, user_id: str) -> bool:
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
                JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS,
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
                JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS,
                JOB_STATUS_PENDING,
                json.dumps({}),
                0,
                now,
                now,
            ),
        )
        return True

    def load_non_archived_periods(self, user_id: str) -> list[dict[str, Any]]:
        rows = self._conn.execute(
            """
            SELECT id
            FROM review_periods
            WHERE user_id = %s
              AND status != %s
            ORDER BY starts_at ASC
            """,
            (user_id, REVIEW_PERIOD_STATUS["archived"]),
        ).fetchall()
        return [{"id": row[0]} for row in rows]

    def load_period_member_data(
        self,
        review_period_id: str,
        *,
        metric_formula_version: str = METRIC_FORMULA_VERSION,
    ) -> tuple[list[int], list[dict[str, Any]]]:
        member_rows = self._conn.execute(
            """
            SELECT g.result, g.id
            FROM review_period_games rpg
            INNER JOIN games g ON g.id = rpg.game_id
            WHERE rpg.review_period_id = %s
            """,
            (review_period_id,),
        ).fetchall()
        results = [int(row[0]) for row in member_rows]
        game_ids = [row[1] for row in member_rows]
        if not game_ids:
            return results, []

        metric_rows = self._conn.execute(
            """
            SELECT DISTINCT ON (gm.game_id)
              gm.game_id,
              gm.average_centipawn_loss,
              gm.user_move_count,
              gm.mistakes_count,
              gm.blunders_count,
              gm.phase_metrics,
              gm.winning_positions_reached,
              gm.winning_positions_converted,
              gm.time_pressure_moves_count,
              gm.time_pressure_mistakes_count,
              gm.fast_moves_count,
              gm.fast_move_mistakes_count,
              gm.critical_moves_count,
              gm.critical_accurate_count
            FROM game_metrics gm
            INNER JOIN analysis_runs ar ON ar.id = gm.analysis_run_id
            WHERE gm.game_id = ANY(%s)
              AND gm.metric_formula_version = %s
              AND ar.status = 2
            ORDER BY gm.game_id, gm.updated_at DESC
            """,
            (game_ids, metric_formula_version),
        ).fetchall()

        game_metrics = [
            {
                "game_id": row[0],
                "average_centipawn_loss": row[1],
                "user_move_count": row[2],
                "mistakes_count": row[3],
                "blunders_count": row[4],
                "phase_metrics": row[5] or {},
                "winning_positions_reached": row[6],
                "winning_positions_converted": row[7],
                "time_pressure_moves_count": row[8],
                "time_pressure_mistakes_count": row[9],
                "fast_moves_count": row[10],
                "fast_move_mistakes_count": row[11],
                "critical_moves_count": row[12],
                "critical_accurate_count": row[13],
            }
            for row in metric_rows
        ]
        return results, game_metrics

    def upsert_review_period_metrics(
        self,
        *,
        user_id: str,
        review_period_id: str,
        metrics: dict[str, Any],
        metric_formula_version: str = METRIC_FORMULA_VERSION,
    ) -> str:
        now = _utcnow()
        existing = self._conn.execute(
            """
            SELECT id FROM review_period_metrics
            WHERE review_period_id = %s AND metric_formula_version = %s
            """,
            (review_period_id, metric_formula_version),
        ).fetchone()
        metric_id = existing[0] if existing else new_ulid()

        fields = (
            int(metrics.get("games_count") or 0),
            int(metrics.get("analyzed_games_count") or 0),
            int(metrics.get("user_move_count") or 0),
            _decimal_or_none(metrics.get("win_rate")),
            _decimal_or_none(metrics.get("draw_rate")),
            _decimal_or_none(metrics.get("loss_rate")),
            _decimal_or_none(metrics.get("average_centipawn_loss")),
            _decimal_or_none(metrics.get("mistakes_per_game")),
            _decimal_or_none(metrics.get("blunders_per_game")),
            json.dumps(metrics.get("phase_metrics") or {}),
            int(metrics.get("winning_positions_reached") or 0),
            int(metrics.get("winning_positions_converted") or 0),
            _decimal_or_none(metrics.get("conversion_rate")),
            int(metrics.get("time_pressure_moves_count") or 0),
            int(metrics.get("time_pressure_mistakes_count") or 0),
            _decimal_or_none(metrics.get("time_pressure_error_rate")),
            int(metrics.get("fast_moves_count") or 0),
            int(metrics.get("fast_move_mistakes_count") or 0),
            _decimal_or_none(metrics.get("fast_move_error_rate")),
            int(metrics.get("critical_moves_count") or 0),
            int(metrics.get("critical_accurate_count") or 0),
            _decimal_or_none(metrics.get("critical_position_accuracy")),
            json.dumps(metrics.get("metadata") or {}),
        )

        if existing:
            self._conn.execute(
                """
                UPDATE review_period_metrics SET
                  games_count = %s,
                  analyzed_games_count = %s,
                  user_move_count = %s,
                  win_rate = %s,
                  draw_rate = %s,
                  loss_rate = %s,
                  average_centipawn_loss = %s,
                  mistakes_per_game = %s,
                  blunders_per_game = %s,
                  phase_metrics = %s::jsonb,
                  winning_positions_reached = %s,
                  winning_positions_converted = %s,
                  conversion_rate = %s,
                  time_pressure_moves_count = %s,
                  time_pressure_mistakes_count = %s,
                  time_pressure_error_rate = %s,
                  fast_moves_count = %s,
                  fast_move_mistakes_count = %s,
                  fast_move_error_rate = %s,
                  critical_moves_count = %s,
                  critical_accurate_count = %s,
                  critical_position_accuracy = %s,
                  metadata = %s::jsonb,
                  updated_at = %s
                WHERE id = %s
                """,
                fields + (now, metric_id),
            )
        else:
            self._conn.execute(
                """
                INSERT INTO review_period_metrics (
                  id, user_id, review_period_id, metric_formula_version,
                  games_count, analyzed_games_count, user_move_count,
                  win_rate, draw_rate, loss_rate,
                  average_centipawn_loss, mistakes_per_game, blunders_per_game,
                  phase_metrics,
                  winning_positions_reached, winning_positions_converted, conversion_rate,
                  time_pressure_moves_count, time_pressure_mistakes_count,
                  time_pressure_error_rate,
                  fast_moves_count, fast_move_mistakes_count, fast_move_error_rate,
                  critical_moves_count, critical_accurate_count,
                  critical_position_accuracy, metadata,
                  created_at, updated_at
                ) VALUES (
                  %s, %s, %s, %s,
                  %s, %s, %s,
                  %s, %s, %s,
                  %s, %s, %s,
                  %s::jsonb,
                  %s, %s, %s,
                  %s, %s,
                  %s,
                  %s, %s, %s,
                  %s, %s,
                  %s, %s::jsonb,
                  %s, %s
                )
                """,
                (metric_id, user_id, review_period_id, metric_formula_version)
                + fields
                + (now, now),
            )
        return metric_id

def persist_game_metrics(conn: psycopg.Connection, analysis_run_id: str) -> dict[str, Any] | None:
    repo = MetricsRepository(conn)
    payload = repo.load_game_metric_inputs(analysis_run_id)
    if payload is None:
        return None

    metrics = compute_game_metrics(
        moves=payload["moves"],
        game_result=payload["game_result"],
        time_class=payload["time_class"],
        time_control=payload["time_control"],
    )
    metric_id = repo.upsert_game_metrics(
        user_id=payload["user_id"],
        game_id=payload["game_id"],
        analysis_run_id=analysis_run_id,
        metrics=metrics,
    )
    enqueued = repo.enqueue_period_refresh_if_needed(payload["user_id"])
    return {
        "game_metric_id": metric_id,
        "game_id": payload["game_id"],
        "user_id": payload["user_id"],
        "user_move_count": metrics["user_move_count"],
        "period_refresh_enqueued": enqueued,
    }


def refresh_user_period_metrics(conn: psycopg.Connection, user_id: str) -> dict[str, Any]:
    repo = MetricsRepository(conn)
    periods = repo.load_non_archived_periods(user_id)
    refreshed: list[str] = []

    for period in periods:
        results, game_metrics = repo.load_period_member_data(period["id"])
        metrics = aggregate_period_metrics(game_rows=game_metrics, member_results=results)
        metric_id = repo.upsert_review_period_metrics(
            user_id=user_id,
            review_period_id=period["id"],
            metrics=metrics,
        )
        refreshed.append(metric_id)

    return {
        "user_id": user_id,
        "periods_refreshed": len(refreshed),
        "review_period_metric_ids": refreshed,
    }
