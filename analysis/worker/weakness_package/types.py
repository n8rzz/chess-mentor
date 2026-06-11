from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class CandidateEventRow:
    id: str
    event_type: int
    severity: float
    confidence: float
    metadata: dict[str, Any]


@dataclass(frozen=True)
class MoveEvaluationRow:
    centipawn_loss: int
    classification: int
    metadata: dict[str, Any]


@dataclass(frozen=True)
class MoveArtifact:
    move_id: str
    game_id: str
    user_id: str
    move_number: int
    san: str
    played_at: datetime
    time_class: int
    candidate_events: tuple[CandidateEventRow, ...] = ()
    evaluation: MoveEvaluationRow | None = None


@dataclass(frozen=True)
class ClassifiedWeakness:
    user_id: str
    game_id: str
    move_id: str
    primary_theme: int
    secondary_theme: int | None
    severity: float
    phase: int
    occurred_under_time_pressure: bool
    explanation_key: str
    metadata: dict[str, Any]
    played_at: datetime


@dataclass
class ThemeAggregation:
    theme: int
    events: list[ClassifiedWeakness] = field(default_factory=list)

    @property
    def occurrences(self) -> int:
        return len(self.events)

    @property
    def games_with_occurrences(self) -> int:
        return len({event.game_id for event in self.events})


@dataclass(frozen=True)
class CycleBuildResult:
    theme: int
    cycle_number: int
    status: int
    baseline_occurrences: int
    current_occurrences: int
    baseline_severity: float
    current_severity: float
    improvement_percentage: float | None
    frequency: float
    detection_window_games: int
    detection_window_days: int
