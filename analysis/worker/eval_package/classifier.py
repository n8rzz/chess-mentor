from __future__ import annotations

from worker.eval_package.constants import (
    CLASSIFICATION,
    CPL_THRESHOLDS,
    MATE_SCORE_CP,
    TIME_CLASS,
    TIME_CONTROL_WEIGHT,
)


def time_control_weight(time_class: int) -> float:
    return TIME_CONTROL_WEIGHT.get(time_class, 1.0)


def mate_to_cp(mate: int | None, *, user_is_white: bool, user_to_move: bool) -> int | None:
    if mate is None:
        return None
    # Engine mate scores are from side-to-move perspective.
    if user_to_move:
        user_mate = mate if user_is_white else -mate
    else:
        user_mate = -mate if user_is_white else mate

    if user_mate > 0:
        return MATE_SCORE_CP - user_mate * 100
    if user_mate < 0:
        return -MATE_SCORE_CP - user_mate * 100
    return 0


def score_to_user_cp(
    *,
    cp: int | None,
    mate: int | None,
    user_is_white: bool,
    white_to_move: bool,
) -> int:
    if mate is not None:
        converted = mate_to_cp(mate, user_is_white=user_is_white, user_to_move=white_to_move == user_is_white)
        return converted if converted is not None else 0
    if cp is None:
        return 0
    if user_is_white:
        return cp
    return -cp


def centipawn_loss(eval_before_cp: int, eval_after_cp: int) -> int:
    return max(0, eval_before_cp - eval_after_cp)


def classify_move(cpl: int) -> int:
    if cpl >= CPL_THRESHOLDS["blunder"]:
        return CLASSIFICATION["blunder"]
    if cpl >= CPL_THRESHOLDS["mistake"]:
        return CLASSIFICATION["mistake"]
    if cpl >= CPL_THRESHOLDS["inaccuracy"]:
        return CLASSIFICATION["inaccuracy"]
    return CLASSIFICATION["good"]


def evaluation_metadata(*, time_class: int, cpl: int) -> dict:
    weight = time_control_weight(time_class)
    return {
        "time_control_weight": weight,
        "weighted_centipawn_loss": round(cpl * weight, 2),
    }
