"""Integer enums and tunable thresholds for the evaluation engine.

All integer values mirror the Rails contract (`Game`, `Move`, `AnalysisRun`,
`MoveEvaluation`, `CandidateEvent`) so Python writers and the UI read the same semantics.

Usage:
    from worker.eval_package.constants import CLASSIFICATION, CPL_THRESHOLDS, EVENT_TYPE

    label = classify_move(cpl)  # returns CLASSIFICATION["mistake"] when cpl >= 100
    repo.insert_candidate_event(..., event_type=EVENT_TYPE["tactical"])
"""

# Which side the user played in a game (`games.user_color`).
# Used by the parser and engine to orient evaluations from the user's perspective.
USER_COLOR = {
    "white": 0,
    "black": 1,
}

# Side to move for each parsed move (`moves.color`).
# Distinct from `USER_COLOR` — a move row records who played that ply.
MOVE_COLOR = {
    "white": 0,
    "black": 1,
}

# Time-control category (`games.time_class`).
# Drives time-pressure detection and CPL weighting in faster formats.
TIME_CLASS = {
    "bullet": 0,
    "blitz": 1,
    "rapid": 2,
    "classical": 3,
    "unknown": 4,
}

# Multiplier applied to centipawn loss before move classification (`classifier.py`).
# Faster time controls are weighted less harshly so bullet/blitz noise does not
# dominate weakness signals. Keyed by `TIME_CLASS` integer.
TIME_CONTROL_WEIGHT = {
    TIME_CLASS["classical"]: 1.0,
    TIME_CLASS["rapid"]: 1.0,
    TIME_CLASS["blitz"]: 0.75,
    TIME_CLASS["bullet"]: 0.25,
    TIME_CLASS["unknown"]: 1.0,
}

# Pipeline status for `analysis_runs.status`.
# Written by `repository.AnalysisRepository` as analysis progresses.
# Must match the Rails `AnalysisRun` enum.
ANALYSIS_RUN_STATUS = {
    "pending": 0,
    "running": 1,
    "succeeded": 2,
    "partially_succeeded": 3,
    "failed": 4,
    "cancelled": 5,
}

# Move quality label persisted on `move_evaluations.classification`.
# Assigned by `classifier.classify_move` from weighted centipawn loss.
# Must match the Rails `MoveEvaluation` enum.
CLASSIFICATION = {
    "good": 0,
    "inaccuracy": 1,
    "mistake": 2,
    "blunder": 3,
}

# Centipawn-loss cutoffs for `classify_move` and detector gates.
# Also re-exported by `weakness_package.constants` for theme-rule consistency.
# Raise a threshold to require larger eval swings before flagging a move.
CPL_THRESHOLDS = {
    "inaccuracy": 50,
    "mistake": 100,
    "blunder": 300,
}

# Candidate-event category persisted on `candidate_events.event_type`.
# Produced by detectors in `eval_package/detectors/`; consumed later by the
# weakness classifier (Milestone 5). Not the same as `WEAKNESS_THEME`.
EVENT_TYPE = {
    "material": 0,
    "tactical": 1,
    "threat": 2,
    "king_safety": 3,
    "pawn_structure": 4,
    "endgame_phase": 5,
    "time_pressure": 6,
}

# Large centipawn stand-in for forced-mate scores (`classifier.mate_to_cp`).
# Keeps mate and centipawn evaluations on a comparable scale for CPL math.
MATE_SCORE_CP = 10_000

# Piece values in pawn units for material-delta detection (`detectors/material.py`).
# Used to compute severity from material lost or gained on a user move.
PIECE_VALUES = {
    "pawn": 1,
    "knight": 3,
    "bishop": 3,
    "rook": 5,
    "queen": 9,
}

# Clock seconds below which a user move counts as time-pressured (`detectors/time_pressure.py`).
# Keyed by `TIME_CLASS`; aligns with weakness-classifier defaults per format.
# Tune per format to match how your imported games report remaining clock.
TIME_PRESSURE_THRESHOLDS_SECONDS = {
    TIME_CLASS["bullet"]: 5,
    TIME_CLASS["blitz"]: 15,
    TIME_CLASS["rapid"]: 60,
    TIME_CLASS["classical"]: 180,
    TIME_CLASS["unknown"]: 60,
}
