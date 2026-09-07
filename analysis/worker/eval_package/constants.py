"""Integer enums and tunable thresholds for the evaluation engine.

All integer values mirror the Rails contract (`Game`, `Move`, `AnalysisRun`,
`MoveEvaluation`, `AnalysisEvent`) so Python writers and the UI read the same semantics.
"""

# Which side the user played in a game (`games.user_color`).
USER_COLOR = {
    "white": 0,
    "black": 1,
}

MOVE_COLOR = {
    "white": 0,
    "black": 1,
}

TIME_CLASS = {
    "bullet": 0,
    "blitz": 1,
    "rapid": 2,
    "classical": 3,
    "unknown": 4,
}

TIME_CONTROL_WEIGHT = {
    TIME_CLASS["classical"]: 1.0,
    TIME_CLASS["rapid"]: 1.0,
    TIME_CLASS["blitz"]: 0.75,
    TIME_CLASS["bullet"]: 0.25,
    TIME_CLASS["unknown"]: 1.0,
}

ANALYSIS_RUN_STATUS = {
    "pending": 0,
    "running": 1,
    "succeeded": 2,
    "partially_succeeded": 3,
    "failed": 4,
    "cancelled": 5,
}

# Written to analysis_runs.metadata["phase"] so the UI can show mid-run progress.
# Keep labels aligned with Rails AnalysisRun::PHASE_LABELS.
ANALYSIS_PHASE = {
    "scan": "scan",
    "deepen": "deepen",
    "detect": "detect",
    "complete": "complete",
}

CLASSIFICATION = {
    "good": 0,
    "inaccuracy": 1,
    "mistake": 2,
    "blunder": 3,
}

CPL_THRESHOLDS = {
    "inaccuracy": 50,
    "mistake": 100,
    "blunder": 300,
}

EVENT_TYPE = {
    "material": 0,
    "tactical": 1,
    "threat": 2,
    "king_safety": 3,
    "pawn_structure": 4,
    "endgame_phase": 5,
    "time_pressure": 6,
    "critical_position": 7,
}

MATE_SCORE_CP = 10_000

PIECE_VALUES = {
    "pawn": 1,
    "knight": 3,
    "bishop": 3,
    "rook": 5,
    "queen": 9,
}

TIME_PRESSURE_THRESHOLDS_SECONDS = {
    TIME_CLASS["bullet"]: 5,
    TIME_CLASS["blitz"]: 15,
    TIME_CLASS["rapid"]: 60,
    TIME_CLASS["classical"]: 180,
    TIME_CLASS["unknown"]: 60,
}

# Keep aligned with Rails AnalysisVersions.
ANALYSIS_VERSION = "1.1.0"
DEPTH_SCAN = 14
DEPTH_CRITICAL = 20
MULTIPV = 3

CRITICAL_CANDIDATE_GAP_CP = 150
CRITICAL_ONLY_MOVE_GAP_CP = 300
CRITICAL_WINNING_CP = 200
CRITICAL_EQUAL_CP = 50
CRITICAL_LOSING_CP = -150
CRITICAL_SCORE_THRESHOLD = 0.35
