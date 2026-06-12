from __future__ import annotations

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class PlanRow:
    id: str
    user_id: str
    weakness_cycle_id: str
    theme: int
    status: int
    starts_at: object | None
    ends_at: object | None
    baseline_occurrences: int
    current_occurrences: int
    improvement_threshold: float | None
    managed_threshold: float | None
    metadata: dict


@dataclass(frozen=True)
class WeaknessEventRow:
    id: str
    game_id: str
    move_id: str
    created_at: object


@dataclass(frozen=True)
class PuzzleRow:
    id: str
    theme: int
    rating: int | None


@dataclass(frozen=True)
class AssignmentDraft:
    assignment_type: int
    due_on: date
    puzzle_id: str | None = None
    source_game_id: str | None = None
    source_move_id: str | None = None
    prompt: str | None = None
    metadata: dict | None = None
