from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import psycopg

from worker.import_package.ids import new_ulid
from worker.training_package.constants import (
    ASSIGNMENT_STATUS,
    IMPROVING_THRESHOLD,
    MANAGED_THRESHOLD,
    PLAN_DURATION_DAYS,
    PUZZLE_SOURCE,
)
from worker.training_package.generator import generate_assignments
from worker.training_package.types import PlanRow, PuzzleRow, WeaknessEventRow


class TrainingRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def load_plan(self, training_plan_id: str) -> PlanRow | None:
        row = self._conn.execute(
            """
            SELECT id, user_id, weakness_cycle_id, theme, status,
                   starts_at, ends_at, baseline_occurrences, current_occurrences,
                   improvement_threshold, managed_threshold, metadata
            FROM training_plans
            WHERE id = %s
            """,
            (training_plan_id,),
        ).fetchone()
        if row is None:
            return None

        return PlanRow(
            id=row[0],
            user_id=row[1],
            weakness_cycle_id=row[2],
            theme=row[3],
            status=row[4],
            starts_at=row[5],
            ends_at=row[6],
            baseline_occurrences=row[7],
            current_occurrences=row[8],
            improvement_threshold=float(row[9]) if row[9] is not None else None,
            managed_threshold=float(row[10]) if row[10] is not None else None,
            metadata=row[11] or {},
        )

    def assignment_count(self, training_plan_id: str) -> int:
        row = self._conn.execute(
            "SELECT COUNT(*) FROM training_assignments WHERE training_plan_id = %s",
            (training_plan_id,),
        ).fetchone()
        return int(row[0]) if row else 0

    def max_day_index(self, training_plan_id: str) -> int | None:
        row = self._conn.execute(
            """
            SELECT MAX((metadata->>'day_index')::int)
            FROM training_assignments
            WHERE training_plan_id = %s
            """,
            (training_plan_id,),
        ).fetchone()
        if row is None or row[0] is None:
            return None
        return int(row[0])

    def load_weakness_events(self, weakness_cycle_id: str) -> list[WeaknessEventRow]:
        rows = self._conn.execute(
            """
            SELECT id, game_id, move_id, created_at
            FROM weakness_events
            WHERE weakness_cycle_id = %s
            ORDER BY created_at DESC, id DESC
            """,
            (weakness_cycle_id,),
        ).fetchall()
        return [
            WeaknessEventRow(id=row[0], game_id=row[1], move_id=row[2], created_at=row[3])
            for row in rows
        ]

    def load_theme_puzzles(self, theme: int) -> list[PuzzleRow]:
        rows = self._conn.execute(
            """
            SELECT id, theme, rating
            FROM puzzles
            WHERE theme = %s AND source = %s
            ORDER BY rating ASC NULLS LAST, id ASC
            """,
            (theme, PUZZLE_SOURCE["curated"]),
        ).fetchall()
        return [PuzzleRow(id=row[0], theme=row[1], rating=row[2]) for row in rows]

    def load_cycle_occurrences(self, weakness_cycle_id: str) -> tuple[int, int]:
        row = self._conn.execute(
            """
            SELECT baseline_occurrences, current_occurrences
            FROM weakness_cycles
            WHERE id = %s
            """,
            (weakness_cycle_id,),
        ).fetchone()
        if row is None:
            raise ValueError(f"weakness_cycle not found: {weakness_cycle_id}")
        return int(row[0]), int(row[1])

    def generate_plan_assignments(
        self,
        training_plan_id: str,
        *,
        extension: bool = False,
    ) -> int:
        plan = self.load_plan(training_plan_id)
        if plan is None:
            raise ValueError(f"training_plan not found: {training_plan_id}")

        existing_count = self.assignment_count(training_plan_id)
        if existing_count > 0 and not extension:
            return 0

        baseline, current = self.load_cycle_occurrences(plan.weakness_cycle_id)
        events = self.load_weakness_events(plan.weakness_cycle_id)
        puzzles = self.load_theme_puzzles(plan.theme)

        now = _utcnow()
        starts_at = plan.starts_at or now
        if isinstance(starts_at, datetime):
            start_date = starts_at.date()
        else:
            start_date = starts_at

        if extension:
            max_day = self.max_day_index(training_plan_id)
            start_day_offset = (max_day + 1) if max_day is not None else PLAN_DURATION_DAYS
            ends_at = plan.ends_at or (starts_at + timedelta(days=PLAN_DURATION_DAYS))
            if isinstance(ends_at, datetime):
                new_ends_at = ends_at + timedelta(days=PLAN_DURATION_DAYS)
            else:
                new_ends_at = ends_at + timedelta(days=PLAN_DURATION_DAYS)
            self._update_plan_schedule(
                training_plan_id,
                starts_at=starts_at,
                ends_at=new_ends_at,
                baseline_occurrences=plan.baseline_occurrences or baseline,
                current_occurrences=current,
            )
        else:
            start_day_offset = 0
            ends_at = starts_at + timedelta(days=PLAN_DURATION_DAYS)
            self._update_plan_schedule(
                training_plan_id,
                starts_at=starts_at,
                ends_at=ends_at,
                baseline_occurrences=baseline,
                current_occurrences=current,
                improvement_threshold=plan.improvement_threshold or IMPROVING_THRESHOLD,
                managed_threshold=plan.managed_threshold or MANAGED_THRESHOLD,
            )

        drafts = generate_assignments(
            plan,
            events,
            puzzles,
            start_day_offset=start_day_offset,
            day_count=PLAN_DURATION_DAYS,
            start_date=start_date,
        )
        return self._insert_assignments(training_plan_id, drafts)

    def _update_plan_schedule(
        self,
        training_plan_id: str,
        *,
        starts_at: datetime,
        ends_at: datetime,
        baseline_occurrences: int,
        current_occurrences: int,
        improvement_threshold: float | None = None,
        managed_threshold: float | None = None,
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE training_plans
            SET starts_at = %s,
                ends_at = %s,
                baseline_occurrences = %s,
                current_occurrences = %s,
                improvement_threshold = COALESCE(%s, improvement_threshold),
                managed_threshold = COALESCE(%s, managed_threshold),
                updated_at = %s
            WHERE id = %s
            """,
            (
                starts_at,
                ends_at,
                baseline_occurrences,
                current_occurrences,
                Decimal(str(improvement_threshold)) if improvement_threshold is not None else None,
                Decimal(str(managed_threshold)) if managed_threshold is not None else None,
                now,
                training_plan_id,
            ),
        )

    def _insert_assignments(self, training_plan_id: str, drafts: list) -> int:
        now = _utcnow()
        for draft in drafts:
            self._conn.execute(
                """
                INSERT INTO training_assignments (
                  id, training_plan_id, assignment_type, status, due_on,
                  source_game_id, source_move_id, puzzle_id, prompt, metadata,
                  created_at, updated_at
                ) VALUES (
                  %s, %s, %s, %s, %s,
                  %s, %s, %s, %s, %s::jsonb,
                  %s, %s
                )
                """,
                (
                    new_ulid(),
                    training_plan_id,
                    draft.assignment_type,
                    ASSIGNMENT_STATUS["pending"],
                    draft.due_on,
                    draft.source_game_id,
                    draft.source_move_id,
                    draft.puzzle_id,
                    draft.prompt,
                    json.dumps(draft.metadata or {}),
                    now,
                    now,
                ),
            )
        return len(drafts)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)
