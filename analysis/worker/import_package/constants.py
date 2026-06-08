"""Shared integer enums matching Rails models."""

PROVIDER = {
    "lichess": 0,
    "chess_com": 1,
}

USER_COLOR = {
    "white": 0,
    "black": 1,
}

RESULT = {
    "win": 0,
    "loss": 1,
    "draw": 2,
    "unknown": 3,
}

TIME_CLASS = {
    "bullet": 0,
    "blitz": 1,
    "rapid": 2,
    "classical": 3,
    "unknown": 4,
}

IMPORT_RECORD_STATUS = {
    "pending": 0,
    "imported": 1,
    "skipped": 2,
    "failed": 3,
}

IMPORT_BATCH_STATUS = {
    "pending": 0,
    "running": 1,
    "succeeded": 2,
    "partially_succeeded": 3,
    "failed": 4,
}

PERF_TO_TIME_CLASS = {
    "bullet": TIME_CLASS["bullet"],
    "blitz": TIME_CLASS["blitz"],
    "rapid": TIME_CLASS["rapid"],
    "classical": TIME_CLASS["classical"],
}
