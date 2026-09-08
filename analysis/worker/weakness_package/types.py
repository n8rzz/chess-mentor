from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class AnalysisEventRow:
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
    eval_before_cp: int | None = None
    eval_after_cp: int | None = None
    best_move_san: str | None = None
    best_move_uci: str | None = None
    critical_position: bool = False
    candidates: Any = None


@dataclass(frozen=True)
class MoveArtifact:
    move_id: str
    game_id: str
    user_id: str
    move_number: int
    san: str
    played_at: datetime
    time_class: int
    ply: int = 0
    phase: int | None = None
    fen_before: str | None = None
    fen_after: str | None = None
    clock_before: int | None = None
    clock_after: int | None = None
    time_control: str | None = None
    opening_eco: str | None = None
    opening_name: str | None = None
    analysis_events: tuple[AnalysisEventRow, ...] = ()
    evaluation: MoveEvaluationRow | None = None


@dataclass(frozen=True)
class ClassifiedPattern:
    user_id: str
    game_id: str
    move_id: str
    primary_pattern: int
    secondary_pattern: int | None
    severity: float
    confidence: float
    phase: int
    occurred_under_time_pressure: bool
    explanation_key: str
    metadata: dict[str, Any]
    played_at: datetime


@dataclass
class PatternAggregation:
    pattern: int
    events: list[ClassifiedPattern] = field(default_factory=list)

    @property
    def occurrences(self) -> int:
        return len(self.events)

    @property
    def games_with_occurrences(self) -> int:
        return len({event.game_id for event in self.events})


@dataclass(frozen=True)
class CycleBuildResult:
    pattern: int
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
