from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import psycopg

from worker.config import load_config
from worker.eval_package.constants import ANALYSIS_RUN_STATUS
from worker.eval_package.engine import CandidateLine, EngineEvaluation
from worker.eval_package.game_phase import classify_game_phases
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
    depth_critical: int
    multipv: int
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
    phase: int | None


class AnalysisRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn
        self._progress_conn: psycopg.Connection | None = None

    def close(self) -> None:
        if self._progress_conn is not None and not self._progress_conn.closed:
            self._progress_conn.close()
        self._progress_conn = None

    def _progress_connection(self) -> psycopg.Connection:
        if self._progress_conn is None or self._progress_conn.closed:
            self._progress_conn = psycopg.connect(load_config().database_url, autocommit=True)
            # Never block the engine loop waiting on the open analysis transaction.
            self._progress_conn.execute("SET lock_timeout = '250ms'")
        return self._progress_conn

    def load_context(self, analysis_run_id: str, game_id: str) -> AnalysisContext:
        row = self._conn.execute(
            """
            SELECT
              ar.id,
              ar.game_id,
              ar.user_id,
              ar.depth,
              ar.depth_critical,
              ar.multipv,
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

        metadata = row[9]
        if isinstance(metadata, str):
            metadata = json.loads(metadata)

        return AnalysisContext(
            analysis_run_id=row[0],
            game_id=row[1],
            user_id=row[2],
            depth=row[3],
            depth_critical=row[4],
            multipv=row[5],
            engine_name=row[6],
            engine_version=row[7],
            analysis_version=row[8],
            metadata=dict(metadata or {}),
            pgn=row[10],
            user_color=row[11],
            time_class=row[12],
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
        # Commit immediately so Rails can show "running" while analysis continues.
        self._conn.commit()

    def set_phase(self, analysis_run_id: str, phase: str, **extra: Any) -> None:
        """Publish phase progress on a separate connection so it is visible mid-transaction.

        Uses a reused autocommit connection with a short lock_timeout so progress
        publishing never stalls the Stockfish loop if the analysis row is locked.
        """
        patch = {"phase": phase, **extra}
        now = _utcnow()
        progress_conn = self._progress_connection()
        try:
            progress_conn.execute(
                """
                UPDATE analysis_runs
                SET metadata = metadata || %s::jsonb, updated_at = %s
                WHERE id = %s
                """,
                (json.dumps(patch), now, analysis_run_id),
            )
        except psycopg.errors.LockNotAvailable:
            # Skip this progress tick; the next one (or terminal status write) will catch up.
            return

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

    def analysis_run_status(self, analysis_run_id: str) -> int:
        row = self._conn.execute(
            "SELECT status FROM analysis_runs WHERE id = %s",
            (analysis_run_id,),
        ).fetchone()
        if row is None:
            raise ValueError(f"analysis run not found: {analysis_run_id}")
        return int(row[0])

    def load_succeeded_summary(self, analysis_run_id: str, game_id: str) -> dict[str, Any]:
        row = self._conn.execute(
            "SELECT metadata FROM analysis_runs WHERE id = %s",
            (analysis_run_id,),
        ).fetchone()
        metadata = row[0] if row else {}
        if isinstance(metadata, str):
            metadata = json.loads(metadata)
        metadata = dict(metadata or {})
        return {
            "analysis_run_id": analysis_run_id,
            "game_id": game_id,
            "status": "succeeded",
            "moves_parsed": metadata.get("moves_parsed", 0),
            "user_moves_evaluated": metadata.get("user_moves_evaluated", 0),
            "events_detected": metadata.get("events_detected", 0),
            "critical_positions": metadata.get("critical_positions", 0),
            "cache_hits": metadata.get("cache_hits", 0),
            "cache_misses": metadata.get("cache_misses", 0),
        }

    def has_move_evaluation(self, analysis_run_id: str, move_id: str) -> bool:
        row = self._conn.execute(
            """
            SELECT 1 FROM move_evaluations
            WHERE analysis_run_id = %s AND move_id = %s
            LIMIT 1
            """,
            (analysis_run_id, move_id),
        ).fetchone()
        return row is not None

    def load_move_evaluation(
        self,
        analysis_run_id: str,
        move_id: str,
    ) -> tuple[EngineEvaluation, int, bool, float] | None:
        row = self._conn.execute(
            """
            SELECT
              eval_before_cp, eval_after_cp, centipawn_loss,
              best_move_uci, best_move_san, principal_variation,
              mate_before, mate_after, candidates, depth,
              critical_position, criticality_score, metadata
            FROM move_evaluations
            WHERE analysis_run_id = %s AND move_id = %s
            LIMIT 1
            """,
            (analysis_run_id, move_id),
        ).fetchone()
        if row is None:
            return None

        candidates_raw = row[8]
        if isinstance(candidates_raw, str):
            candidates_raw = json.loads(candidates_raw)
        candidates = tuple(
            CandidateLine(
                rank=int(item.get("rank", index)),
                move_uci=item.get("move_uci"),
                move_san=item.get("move_san"),
                eval_cp=int(item.get("eval_cp", 0)),
                mate=item.get("mate"),
                pv_san=item.get("pv_san"),
            )
            for index, item in enumerate(candidates_raw or [], start=1)
        )
        metadata = row[12]
        if isinstance(metadata, str):
            metadata = json.loads(metadata)
        metadata = dict(metadata or {})

        evaluation = EngineEvaluation(
            eval_before_cp=int(row[0]),
            eval_after_cp=int(row[1]),
            mate_before=row[6],
            mate_after=row[7],
            best_move_uci=row[3],
            best_move_san=row[4],
            principal_variation=row[5],
            candidates=candidates,
            depth=row[9],
            multipv=metadata.get("multipv"),
            played_is_best=metadata.get("played_is_best"),
        )
        return evaluation, int(row[2]), bool(row[10]), float(row[11] or 0)

    def move_has_analysis_events(self, analysis_run_id: str, move_id: str) -> bool:
        row = self._conn.execute(
            """
            SELECT 1 FROM analysis_events
            WHERE analysis_run_id = %s AND move_id = %s
            LIMIT 1
            """,
            (analysis_run_id, move_id),
        ).fetchone()
        return row is not None

    def count_analysis_events(self, analysis_run_id: str) -> int:
        row = self._conn.execute(
            "SELECT COUNT(*) FROM analysis_events WHERE analysis_run_id = %s",
            (analysis_run_id,),
        ).fetchone()
        return int(row[0]) if row else 0

    def game_has_moves(self, game_id: str) -> bool:
        row = self._conn.execute(
            "SELECT 1 FROM moves WHERE game_id = %s LIMIT 1",
            (game_id,),
        ).fetchone()
        return row is not None

    def insert_moves(self, game_id: str, positions: list) -> None:
        now = _utcnow()
        phases = classify_game_phases(positions)
        for position, phase in zip(positions, phases, strict=True):
            parsed = position.parsed
            self._conn.execute(
                """
                INSERT INTO moves (
                  id, game_id, ply, move_number, color, san, uci,
                  fen_before, fen_after, played_by_user, phase,
                  clock_before, clock_after, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (game_id, ply) DO UPDATE
                  SET phase = EXCLUDED.phase,
                      updated_at = EXCLUDED.updated_at
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
                    phase,
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
              fen_before, fen_after, played_by_user, clock_before, clock_after, phase
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
                phase=row[12],
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
        candidates: list[dict[str, Any]] | None = None,
        critical_position: bool = False,
        criticality_score: float = 0.0,
        multipv: int | None = None,
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO move_evaluations (
              id, analysis_run_id, game_id, move_id,
              eval_before_cp, eval_after_cp, centipawn_loss, classification,
              best_move_uci, best_move_san, principal_variation,
              mate_before, mate_after, depth, metadata,
              candidates, critical_position, criticality_score,
              created_at, updated_at
            ) VALUES (
              %s, %s, %s, %s,
              %s, %s, %s, %s,
              %s, %s, %s,
              %s, %s, %s, %s::jsonb,
              %s::jsonb, %s, %s,
              %s, %s
            )
            ON CONFLICT (analysis_run_id, move_id) DO NOTHING
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
                json.dumps({**metadata, **({"multipv": multipv} if multipv is not None else {})}),
                json.dumps(candidates or []),
                critical_position,
                criticality_score,
                now,
                now,
            ),
        )

    def update_move_evaluation(
        self,
        *,
        analysis_run_id: str,
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
        candidates: list[dict[str, Any]],
        critical_position: bool,
        criticality_score: float,
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE move_evaluations
            SET eval_before_cp = %s,
                eval_after_cp = %s,
                centipawn_loss = %s,
                classification = %s,
                best_move_uci = %s,
                best_move_san = %s,
                principal_variation = %s,
                mate_before = %s,
                mate_after = %s,
                depth = %s,
                metadata = %s::jsonb,
                candidates = %s::jsonb,
                critical_position = %s,
                criticality_score = %s,
                updated_at = %s
            WHERE analysis_run_id = %s AND move_id = %s
            """,
            (
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
                json.dumps(candidates),
                critical_position,
                criticality_score,
                now,
                analysis_run_id,
                move_id,
            ),
        )

    def insert_analysis_event(
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
            INSERT INTO analysis_events (
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
