from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any

import psycopg

from worker.import_package.ids import new_ulid
from worker.weakness_package.constants import (
    CYCLE_STATUS,
    DETECTION_WINDOW_DAYS,
    DETECTION_WINDOW_GAMES,
    JOB_STATUS_CLAIMED,
    JOB_STATUS_PENDING,
    JOB_STATUS_PROCESSING,
    JOB_TYPE_CLASSIFY_PATTERNS,
    PATTERN_CLASSIFIER_NAME,
    PATTERN_CLASSIFIER_VERSION,
    PATTERN_TAXONOMY_VERSION,
)
from worker.weakness_package.types import (
    AnalysisEventRow,
    ClassifiedPattern,
    CycleBuildResult,
    MoveArtifact,
    MoveEvaluationRow,
)


class PatternRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def load_window_artifacts(self, user_id: str) -> tuple[list[MoveArtifact], int]:
        games = self._load_window_games(user_id)
        if not games:
            return [], 0

        artifacts: list[MoveArtifact] = []
        for game in games:
            artifacts.extend(self._load_game_artifacts(game))

        return artifacts, len(games)

    def load_archived_cycle_numbers(self, user_id: str) -> dict[int, int]:
        rows = self._conn.execute(
            """
            SELECT pattern, MAX(cycle_number) AS max_cycle
            FROM pattern_cycles
            WHERE user_id = %s AND status = %s
            GROUP BY pattern
            """,
            (user_id, CYCLE_STATUS["archived"]),
        ).fetchall()
        return {row[0]: int(row[1]) for row in rows}

    def clear_rebuildable_cycles(self, user_id: str) -> None:
        self._conn.execute(
            """
            DELETE FROM pattern_occurrences
            WHERE user_id = %s
              AND pattern_cycle_id IN (
                SELECT id FROM pattern_cycles
                WHERE user_id = %s AND status != %s
              )
            """,
            (user_id, user_id, CYCLE_STATUS["archived"]),
        )
        self._conn.execute(
            """
            DELETE FROM pattern_cycles
            WHERE user_id = %s AND status != %s
            """,
            (user_id, CYCLE_STATUS["archived"]),
        )

    def insert_cycle_with_events(
        self,
        user_id: str,
        cycle: CycleBuildResult,
        events: list[ClassifiedPattern],
    ) -> str:
        now = _utcnow()
        cycle_id = new_ulid()
        self._conn.execute(
            """
            INSERT INTO pattern_cycles (
              id, user_id, pattern, status, cycle_number,
              baseline_occurrences, current_occurrences,
              baseline_severity, current_severity,
              improvement_percentage,
              detection_window_games, detection_window_days,
              started_at, ended_at, metadata,
              created_at, updated_at
            ) VALUES (
              %s, %s, %s, %s, %s,
              %s, %s,
              %s, %s,
              %s,
              %s, %s,
              %s, %s, %s::jsonb,
              %s, %s
            )
            """,
            (
                cycle_id,
                user_id,
                cycle.pattern,
                cycle.status,
                cycle.cycle_number,
                cycle.baseline_occurrences,
                cycle.current_occurrences,
                cycle.baseline_severity,
                cycle.current_severity,
                cycle.improvement_percentage,
                cycle.detection_window_games,
                cycle.detection_window_days,
                now,
                None,
                json.dumps({"frequency": cycle.frequency}),
                now,
                now,
            ),
        )

        for event in events:
            self._insert_pattern_occurrence(user_id=user_id, cycle_id=cycle_id, event=event)

        return cycle_id

    def enqueue_classification_if_needed(self, user_id: str) -> bool:
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
                JOB_TYPE_CLASSIFY_PATTERNS,
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
                JOB_TYPE_CLASSIFY_PATTERNS,
                JOB_STATUS_PENDING,
                json.dumps({}),
                0,
                now,
                now,
            ),
        )
        return True

    def _insert_pattern_occurrence(self, *, user_id: str, cycle_id: str, event: ClassifiedPattern) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO pattern_occurrences (
              id, user_id, game_id, move_id, pattern_cycle_id,
              primary_pattern, secondary_pattern, severity, confidence, phase,
              occurred_under_time_pressure, explanation_key, metadata,
              classifier, classifier_version, pattern_taxonomy_version,
              created_at, updated_at
            ) VALUES (
              %s, %s, %s, %s, %s,
              %s, %s, %s, %s, %s,
              %s, %s, %s::jsonb,
              %s, %s, %s,
              %s, %s
            )
            """,
            (
                new_ulid(),
                user_id,
                event.game_id,
                event.move_id,
                cycle_id,
                event.primary_pattern,
                None,
                event.severity,
                event.confidence,
                event.phase,
                event.occurred_under_time_pressure,
                event.explanation_key,
                json.dumps(event.metadata),
                PATTERN_CLASSIFIER_NAME,
                PATTERN_CLASSIFIER_VERSION,
                PATTERN_TAXONOMY_VERSION,
                now,
                now,
            ),
        )

    def _load_window_games(self, user_id: str) -> list[dict[str, Any]]:
        cutoff = _utcnow() - timedelta(days=DETECTION_WINDOW_DAYS)
        rows = self._conn.execute(
            """
            SELECT DISTINCT ON (g.id)
              g.id,
              g.user_id,
              g.played_at,
              g.time_class,
              g.time_control,
              g.opening_eco,
              g.opening_name,
              ar.id AS analysis_run_id
            FROM games g
            JOIN analysis_runs ar ON ar.game_id = g.id AND ar.status = 2
            WHERE g.user_id = %s
              AND g.played_at >= %s
            ORDER BY g.id, ar.created_at DESC
            """,
            (user_id, cutoff),
        ).fetchall()

        games = [
            {
                "game_id": row[0],
                "user_id": row[1],
                "played_at": row[2],
                "time_class": row[3],
                "time_control": row[4],
                "opening_eco": row[5],
                "opening_name": row[6],
                "analysis_run_id": row[7],
            }
            for row in rows
        ]
        games.sort(key=lambda item: item["played_at"], reverse=True)
        return games[:DETECTION_WINDOW_GAMES]

    def _load_game_artifacts(self, game: dict[str, Any]) -> list[MoveArtifact]:
        move_rows = self._conn.execute(
            """
            SELECT id, ply, move_number, san, phase, fen_before, fen_after,
                   clock_before, clock_after
            FROM moves
            WHERE game_id = %s AND played_by_user = TRUE
            ORDER BY ply ASC
            """,
            (game["game_id"],),
        ).fetchall()

        artifacts: list[MoveArtifact] = []
        for (
            move_id,
            ply,
            move_number,
            san,
            phase,
            fen_before,
            fen_after,
            clock_before,
            clock_after,
        ) in move_rows:
            events = self._load_analysis_events(game["analysis_run_id"], move_id)
            evaluation = self._load_move_evaluation(game["analysis_run_id"], move_id)
            artifacts.append(
                MoveArtifact(
                    move_id=move_id,
                    game_id=game["game_id"],
                    user_id=game["user_id"],
                    move_number=move_number,
                    san=san,
                    played_at=game["played_at"],
                    time_class=game["time_class"],
                    ply=int(ply),
                    phase=phase,
                    fen_before=fen_before,
                    fen_after=fen_after,
                    clock_before=clock_before,
                    clock_after=clock_after,
                    time_control=game.get("time_control"),
                    opening_eco=game.get("opening_eco"),
                    opening_name=game.get("opening_name"),
                    analysis_events=tuple(events),
                    evaluation=evaluation,
                )
            )
        return artifacts

    def _load_analysis_events(self, analysis_run_id: str, move_id: str) -> list[AnalysisEventRow]:
        rows = self._conn.execute(
            """
            SELECT id, event_type, severity, confidence, metadata
            FROM analysis_events
            WHERE analysis_run_id = %s AND move_id = %s
            """,
            (analysis_run_id, move_id),
        ).fetchall()

        return [_row_to_analysis_event(row) for row in rows]

    def _load_move_evaluation(self, analysis_run_id: str, move_id: str) -> MoveEvaluationRow | None:
        row = self._conn.execute(
            """
            SELECT centipawn_loss, classification, metadata,
                   eval_before_cp, eval_after_cp,
                   best_move_san, best_move_uci, critical_position, candidates
            FROM move_evaluations
            WHERE analysis_run_id = %s AND move_id = %s
            LIMIT 1
            """,
            (analysis_run_id, move_id),
        ).fetchone()
        if row is None:
            return None

        metadata = row[2]
        if isinstance(metadata, str):
            metadata = json.loads(metadata)
        candidates = row[8]
        if isinstance(candidates, str):
            candidates = json.loads(candidates)
        return MoveEvaluationRow(
            centipawn_loss=int(row[0]),
            classification=int(row[1]),
            metadata=dict(metadata or {}),
            eval_before_cp=row[3],
            eval_after_cp=row[4],
            best_move_san=row[5],
            best_move_uci=row[6],
            critical_position=bool(row[7]) if row[7] is not None else False,
            candidates=candidates,
        )


def _row_to_analysis_event(row: tuple[Any, ...]) -> AnalysisEventRow:
    metadata = row[4]
    if isinstance(metadata, str):
        metadata = json.loads(metadata)
    return AnalysisEventRow(
        id=row[0],
        event_type=int(row[1]),
        severity=float(row[2]),
        confidence=float(row[3]),
        metadata=dict(metadata or {}),
    )


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)
