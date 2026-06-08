"""Integer enums and thresholds matching Rails models."""

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
