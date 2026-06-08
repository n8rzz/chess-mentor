from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import psycopg

from worker.eval_package.constants import ANALYSIS_RUN_STATUS
from worker.import_package.ids import new_ulid


@dataclass(frozen=True)
class AnalysisContext:
    analysis_run_id: str
    game_id: str
    user_id: str
    pgn: str
    user_color: int
    time_class: int
    depth: int
    engine_name: str
    engine_version: str
    analysis_version: str
    metadata: dict[str, Any]


@dataclass(frozen=True)
class StoredMove:
    id: str
    game_id: str
    ply: int
    move_number: int
    color: int
    san: str
    uci: str
    fen_before: str
    fen_after: str
    played_by_user: bool
    clock_before: int | None
    clock_after: int | None


class AnalysisRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def load_context(self, analysis_run_id: str, game_id: str) -> AnalysisContext:
        row = self._conn.execute(
            """
            SELECT
              ar.id,
              ar.game_id,
              ar.user_id,
              ar.depth,
              ar.engine_name,
              ar.engine_version,
              ar.analysis_version,
              ar.metadata,
              g.pgn,
              g.user_color,
              g.time_class
            FROM analysis_runs ar
            JOIN games g ON g.id = ar.game_id
            WHERE ar.id = %s AND ar.game_id = %s
            """,
            (analysis_run_id, game_id),
        ).fetchone()

        if row is None:
            raise ValueError(f"analysis run not found: {analysis_run_id}")

        metadata = row[7]
        if isinstance(metadata, str):
            metadata = json.loads(metadata)

        return AnalysisContext(
            analysis_run_id=row[0],
            game_id=row[1],
            user_id=row[2],
            depth=row[3],
            engine_name=row[4],
            engine_version=row[5],
            analysis_version=row[6],
            metadata=dict(metadata or {}),
            pgn=row[8],
            user_color=row[9],
            time_class=row[10],
        )

    def mark_running(self, analysis_run_id: str) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE analysis_runs
            SET status = %s, started_at = %s, updated_at = %s
            WHERE id = %s
            """,
            (ANALYSIS_RUN_STATUS["running"], now, now, analysis_run_id),
        )

    def mark_succeeded(self, analysis_run_id: str, *, metadata_patch: dict[str, Any] | None = None) -> None:
        now = _utcnow()
        if metadata_patch:
            self._conn.execute(
                """
                UPDATE analysis_runs
                SET status = %s,
                    finished_at = %s,
                    updated_at = %s,
                    metadata = metadata || %s::jsonb
                WHERE id = %s
                """,
                (
                    ANALYSIS_RUN_STATUS["succeeded"],
                    now,
                    now,
                    json.dumps(metadata_patch),
                    analysis_run_id,
                ),
            )
        else:
            self._conn.execute(
                """
                UPDATE analysis_runs
                SET status = %s, finished_at = %s, updated_at = %s
                WHERE id = %s
                """,
                (ANALYSIS_RUN_STATUS["succeeded"], now, now, analysis_run_id),
            )

    def mark_failed(
        self,
        analysis_run_id: str,
        *,
        error_message: str,
        error_details: dict[str, Any] | None = None,
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE analysis_runs
            SET status = %s,
                finished_at = %s,
                updated_at = %s,
                error_message = %s,
                error_details = %s::jsonb
            WHERE id = %s
            """,
            (
                ANALYSIS_RUN_STATUS["failed"],
                now,
                now,
                error_message,
                json.dumps(error_details or {}),
                analysis_run_id,
            ),
        )

    def game_has_moves(self, game_id: str) -> bool:
        row = self._conn.execute(
            "SELECT 1 FROM moves WHERE game_id = %s LIMIT 1",
            (game_id,),
        ).fetchone()
        return row is not None

    def insert_moves(self, game_id: str, positions: list) -> None:
        now = _utcnow()
        for position in positions:
            parsed = position.parsed
            self._conn.execute(
                """
                INSERT INTO moves (
                  id, game_id, ply, move_number, color, san, uci,
                  fen_before, fen_after, played_by_user,
                  clock_before, clock_after, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    new_ulid(),
                    game_id,
                    parsed.ply,
                    parsed.move_number,
                    parsed.color,
                    parsed.san,
                    parsed.uci,
                    position.fen_before,
                    position.fen_after,
                    parsed.played_by_user,
                    parsed.clock_before,
                    parsed.clock_after,
                    now,
                    now,
                ),
            )

    def load_moves(self, game_id: str) -> list[StoredMove]:
        rows = self._conn.execute(
            """
            SELECT
              id, game_id, ply, move_number, color, san, uci,
              fen_before, fen_after, played_by_user, clock_before, clock_after
            FROM moves
            WHERE game_id = %s
            ORDER BY ply ASC
            """,
            (game_id,),
        ).fetchall()

        return [
            StoredMove(
                id=row[0],
                game_id=row[1],
                ply=row[2],
                move_number=row[3],
                color=row[4],
                san=row[5],
                uci=row[6],
                fen_before=row[7],
                fen_after=row[8],
                played_by_user=row[9],
                clock_before=row[10],
                clock_after=row[11],
            )
            for row in rows
        ]

    def insert_move_evaluation(
        self,
        *,
        analysis_run_id: str,
        game_id: str,
        move_id: str,
        depth: int,
        eval_before_cp: int,
        eval_after_cp: int,
        centipawn_loss: int,
        classification: int,
        best_move_uci: str | None,
        best_move_san: str | None,
        principal_variation: str | None,
        mate_before: int | None,
        mate_after: int | None,
        metadata: dict[str, Any],
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO move_evaluations (
              id, analysis_run_id, game_id, move_id,
              eval_before_cp, eval_after_cp, centipawn_loss, classification,
              best_move_uci, best_move_san, principal_variation,
              mate_before, mate_after, depth, metadata,
              created_at, updated_at
            ) VALUES (
              %s, %s, %s, %s,
              %s, %s, %s, %s,
              %s, %s, %s,
              %s, %s, %s, %s::jsonb,
              %s, %s
            )
            """,
            (
                new_ulid(),
                analysis_run_id,
                game_id,
                move_id,
                eval_before_cp,
                eval_after_cp,
                centipawn_loss,
                classification,
                best_move_uci,
                best_move_san,
                principal_variation,
                mate_before,
                mate_after,
                depth,
                json.dumps(metadata),
                now,
                now,
            ),
        )

    def insert_candidate_event(
        self,
        *,
        analysis_run_id: str,
        game_id: str,
        move_id: str,
        event_type: int,
        severity: float,
        confidence: float,
        metadata: dict[str, Any],
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO candidate_events (
              id, analysis_run_id, game_id, move_id,
              event_type, severity, confidence, metadata,
              created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
            """,
            (
                new_ulid(),
                analysis_run_id,
                game_id,
                move_id,
                event_type,
                severity,
                confidence,
                json.dumps(metadata),
                now,
                now,
            ),
        )


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)
