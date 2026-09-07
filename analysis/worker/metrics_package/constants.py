"""Integer enums and tunable thresholds for performance metrics.

Keep METRIC_FORMULA_VERSION aligned with Rails AnalysisVersions.
"""

from __future__ import annotations

from worker.eval_package.constants import (
    CLASSIFICATION,
    EVENT_TYPE,
    TIME_CLASS,
    TIME_PRESSURE_THRESHOLDS_SECONDS,
)
from worker.eval_package.game_phase import GAME_PHASE, PHASE_LABELS

# Keep aligned with Rails AnalysisVersions::METRIC_FORMULA_VERSION.
METRIC_FORMULA_VERSION = "1.0.0"

JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS = 5

JOB_STATUS_PENDING = 0
JOB_STATUS_CLAIMED = 1
JOB_STATUS_PROCESSING = 2

REVIEW_PERIOD_STATUS = {
    "draft": 0,
    "active": 1,
    "completed": 2,
    "archived": 3,
}

GAME_RESULT = {
    "win": 0,
    "loss": 1,
    "draw": 2,
    "unknown": 3,
}

WINNING_CP = 200
WINNING_CONSECUTIVE_MOVES = 2
CONVERSION_EQUAL_FLOOR_CP = 75

FAST_MOVE_MIN_CLOCK_SECONDS = 30
FAST_MOVE_THINK_SECONDS = {
    TIME_CLASS["bullet"]: 2,
    TIME_CLASS["blitz"]: 2,
    TIME_CLASS["rapid"]: 3,
    TIME_CLASS["classical"]: 3,
    TIME_CLASS["unknown"]: 3,
}

PHASE_KEYS = ("opening", "middlegame", "endgame")

__all__ = [
    "METRIC_FORMULA_VERSION",
    "JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS",
    "JOB_STATUS_PENDING",
    "JOB_STATUS_CLAIMED",
    "JOB_STATUS_PROCESSING",
    "REVIEW_PERIOD_STATUS",
    "GAME_RESULT",
    "WINNING_CP",
    "WINNING_CONSECUTIVE_MOVES",
    "CONVERSION_EQUAL_FLOOR_CP",
    "FAST_MOVE_MIN_CLOCK_SECONDS",
    "FAST_MOVE_THINK_SECONDS",
    "PHASE_KEYS",
    "CLASSIFICATION",
    "EVENT_TYPE",
    "TIME_CLASS",
    "TIME_PRESSURE_THRESHOLDS_SECONDS",
    "GAME_PHASE",
    "PHASE_LABELS",
]
