from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from worker.metrics_package.constants import (
    CLASSIFICATION,
    CONVERSION_EQUAL_FLOOR_CP,
    FAST_MOVE_MIN_CLOCK_SECONDS,
    FAST_MOVE_THINK_SECONDS,
    GAME_PHASE,
    GAME_RESULT,
    PHASE_KEYS,
    PHASE_LABELS,
    TIME_PRESSURE_THRESHOLDS_SECONDS,
    WINNING_CONSECUTIVE_MOVES,
    WINNING_CP,
)


@dataclass(frozen=True)
class MoveMetricInput:
    move_id: str
    ply: int
    phase: int | None
    clock_before: int | None
    clock_after: int | None
    centipawn_loss: int
    classification: int
    critical_position: bool
    eval_before_cp: int | None
    eval_after_cp: int | None
    has_time_pressure_event: bool


def parse_increment_seconds(time_control: str | None) -> int:
    """Parse Lichess-style time controls like '180+2' or '600+0'."""
    if not time_control:
        return 0
    if "+" not in time_control:
        return 0
    try:
        return max(0, int(time_control.split("+", 1)[1]))
    except ValueError:
        return 0


def think_time_seconds(
    *,
    clock_before: int | None,
    clock_after: int | None,
    increment: int,
) -> int | None:
    if clock_before is None or clock_after is None:
        return None
    return clock_before - clock_after + increment


def _rate(numerator: int, denominator: int) -> Decimal | None:
    if denominator <= 0:
        return None
    return (Decimal(numerator) / Decimal(denominator)).quantize(Decimal("0.0001"))


def _empty_phase_bucket() -> dict[str, Any]:
    return {"moves": 0, "acpl": None, "mistakes": 0, "blunders": 0, "cpl_sum": 0}


def compute_game_metrics(
    *,
    moves: list[MoveMetricInput],
    game_result: int,
    time_class: int,
    time_control: str | None,
) -> dict[str, Any]:
    increment = parse_increment_seconds(time_control)
    pressure_threshold = TIME_PRESSURE_THRESHOLDS_SECONDS.get(time_class, 60)
    fast_think_limit = FAST_MOVE_THINK_SECONDS.get(time_class, 3)

    user_move_count = len(moves)
    cpl_sum = 0
    inaccuracies = 0
    mistakes = 0
    blunders = 0

    phase_buckets: dict[str, dict[str, Any]] = {key: _empty_phase_bucket() for key in PHASE_KEYS}

    time_pressure_moves = 0
    time_pressure_mistakes = 0
    fast_moves = 0
    fast_move_mistakes = 0
    critical_moves = 0
    critical_accurate = 0
    moves_with_clocks = 0

    for move in moves:
        cpl_sum += move.centipawn_loss
        if move.classification == CLASSIFICATION["inaccuracy"]:
            inaccuracies += 1
        if move.classification >= CLASSIFICATION["mistake"]:
            mistakes += 1
        if move.classification == CLASSIFICATION["blunder"]:
            blunders += 1

        phase_key = PHASE_LABELS.get(move.phase) if move.phase is not None else None
        if phase_key in phase_buckets:
            bucket = phase_buckets[phase_key]
            bucket["moves"] += 1
            bucket["cpl_sum"] += move.centipawn_loss
            if move.classification >= CLASSIFICATION["mistake"]:
                bucket["mistakes"] += 1
            if move.classification == CLASSIFICATION["blunder"]:
                bucket["blunders"] += 1

        if move.critical_position:
            critical_moves += 1
            if move.classification == CLASSIFICATION["good"]:
                critical_accurate += 1

        in_time_pressure = move.has_time_pressure_event or (
            move.clock_before is not None and move.clock_before <= pressure_threshold
        )
        if in_time_pressure:
            time_pressure_moves += 1
            if move.classification >= CLASSIFICATION["mistake"]:
                time_pressure_mistakes += 1

        if move.clock_before is not None and move.clock_after is not None:
            moves_with_clocks += 1

        think = think_time_seconds(
            clock_before=move.clock_before,
            clock_after=move.clock_after,
            increment=increment,
        )
        if (
            think is not None
            and think <= fast_think_limit
            and move.clock_before is not None
            and move.clock_before >= FAST_MOVE_MIN_CLOCK_SECONDS
            and move.phase != GAME_PHASE["opening"]
        ):
            fast_moves += 1
            if move.classification >= CLASSIFICATION["mistake"]:
                fast_move_mistakes += 1

    for bucket in phase_buckets.values():
        if bucket["moves"] > 0:
            bucket["acpl"] = float(
                (Decimal(bucket["cpl_sum"]) / Decimal(bucket["moves"])).quantize(Decimal("0.01"))
            )
        del bucket["cpl_sum"]

    reached, converted = compute_conversion(
        moves=moves,
        game_result=game_result,
    )

    average_cpl = None
    if user_move_count > 0:
        average_cpl = (Decimal(cpl_sum) / Decimal(user_move_count)).quantize(Decimal("0.01"))

    return {
        "average_centipawn_loss": average_cpl,
        "user_move_count": user_move_count,
        "inaccuracies_count": inaccuracies,
        "mistakes_count": mistakes,
        "blunders_count": blunders,
        "phase_metrics": phase_buckets,
        "winning_positions_reached": reached,
        "winning_positions_converted": converted,
        "time_pressure_moves_count": time_pressure_moves,
        "time_pressure_mistakes_count": time_pressure_mistakes,
        "time_pressure_error_rate": _rate(time_pressure_mistakes, time_pressure_moves),
        "fast_moves_count": fast_moves,
        "fast_move_mistakes_count": fast_move_mistakes,
        "fast_move_error_rate": _rate(fast_move_mistakes, fast_moves),
        "critical_moves_count": critical_moves,
        "critical_accurate_count": critical_accurate,
        "critical_position_accuracy": _rate(critical_accurate, critical_moves),
        "metadata": {
            "increment_seconds": increment,
            "time_pressure_threshold_seconds": pressure_threshold,
            "fast_think_limit_seconds": fast_think_limit,
            "moves_with_clocks": moves_with_clocks,
            "clock_coverage": moves_with_clocks == user_move_count and user_move_count > 0,
        },
    }


def compute_conversion(
    *,
    moves: list[MoveMetricInput],
    game_result: int,
) -> tuple[int, int]:
    """Return (winning_positions_reached, winning_positions_converted)."""
    ordered = sorted(moves, key=lambda item: item.ply)
    reached = 0
    converted = 0

    consecutive_winning = 0
    in_episode = False
    episode_lost = False

    def close_episode() -> None:
        nonlocal reached, converted, in_episode, episode_lost
        if not in_episode:
            return
        reached += 1
        if not episode_lost and game_result == GAME_RESULT["win"]:
            converted += 1
        in_episode = False
        episode_lost = False

    for move in ordered:
        before = move.eval_before_cp
        after = move.eval_after_cp

        if before is not None and before >= WINNING_CP:
            consecutive_winning += 1
        else:
            consecutive_winning = 0

        if not in_episode and consecutive_winning >= WINNING_CONSECUTIVE_MOVES:
            in_episode = True
            episode_lost = False

        if in_episode:
            dropped = False
            if before is not None and before < CONVERSION_EQUAL_FLOOR_CP:
                dropped = True
            if after is not None and after < CONVERSION_EQUAL_FLOOR_CP:
                dropped = True
            if dropped:
                episode_lost = True
                close_episode()
                consecutive_winning = 0

    close_episode()
    return reached, converted


def aggregate_period_metrics(
    *,
    game_rows: list[dict[str, Any]],
    member_results: list[int],
) -> dict[str, Any]:
    games_count = len(member_results)
    analyzed = [row for row in game_rows if row.get("user_move_count", 0) >= 0]
    analyzed_games_count = len(analyzed)

    known = [result for result in member_results if result != GAME_RESULT["unknown"]]
    known_count = len(known)
    wins = sum(1 for result in known if result == GAME_RESULT["win"])
    draws = sum(1 for result in known if result == GAME_RESULT["draw"])
    losses = sum(1 for result in known if result == GAME_RESULT["loss"])

    user_move_count = sum(int(row.get("user_move_count") or 0) for row in analyzed)
    cpl_weighted = Decimal(0)
    mistakes_total = 0
    blunders_total = 0
    reached = 0
    converted = 0
    tp_moves = 0
    tp_mistakes = 0
    fast_moves = 0
    fast_mistakes = 0
    critical_moves = 0
    critical_accurate = 0

    phase_buckets: dict[str, dict[str, Any]] = {
        key: {"moves": 0, "mistakes": 0, "blunders": 0, "cpl_sum": Decimal(0)} for key in PHASE_KEYS
    }

    for row in analyzed:
        moves = int(row.get("user_move_count") or 0)
        acpl = row.get("average_centipawn_loss")
        if acpl is not None and moves > 0:
            cpl_weighted += Decimal(str(acpl)) * Decimal(moves)
        mistakes_total += int(row.get("mistakes_count") or 0)
        blunders_total += int(row.get("blunders_count") or 0)
        reached += int(row.get("winning_positions_reached") or 0)
        converted += int(row.get("winning_positions_converted") or 0)
        tp_moves += int(row.get("time_pressure_moves_count") or 0)
        tp_mistakes += int(row.get("time_pressure_mistakes_count") or 0)
        fast_moves += int(row.get("fast_moves_count") or 0)
        fast_mistakes += int(row.get("fast_move_mistakes_count") or 0)
        critical_moves += int(row.get("critical_moves_count") or 0)
        critical_accurate += int(row.get("critical_accurate_count") or 0)

        phase_metrics = row.get("phase_metrics") or {}
        for key in PHASE_KEYS:
            bucket = phase_metrics.get(key) or {}
            phase_moves = int(bucket.get("moves") or 0)
            if phase_moves <= 0:
                continue
            phase_buckets[key]["moves"] += phase_moves
            phase_buckets[key]["mistakes"] += int(bucket.get("mistakes") or 0)
            phase_buckets[key]["blunders"] += int(bucket.get("blunders") or 0)
            phase_acpl = bucket.get("acpl")
            if phase_acpl is not None:
                phase_buckets[key]["cpl_sum"] += Decimal(str(phase_acpl)) * Decimal(phase_moves)

    phase_out: dict[str, Any] = {}
    for key, bucket in phase_buckets.items():
        moves = bucket["moves"]
        acpl = None
        if moves > 0:
            acpl = float((bucket["cpl_sum"] / Decimal(moves)).quantize(Decimal("0.01")))
        phase_out[key] = {
            "moves": moves,
            "acpl": acpl,
            "mistakes": bucket["mistakes"],
            "blunders": bucket["blunders"],
        }

    average_cpl = None
    if user_move_count > 0:
        average_cpl = (cpl_weighted / Decimal(user_move_count)).quantize(Decimal("0.01"))

    mistakes_per_game = None
    blunders_per_game = None
    if analyzed_games_count > 0:
        mistakes_per_game = (Decimal(mistakes_total) / Decimal(analyzed_games_count)).quantize(
            Decimal("0.0001")
        )
        blunders_per_game = (Decimal(blunders_total) / Decimal(analyzed_games_count)).quantize(
            Decimal("0.0001")
        )

    return {
        "games_count": games_count,
        "analyzed_games_count": analyzed_games_count,
        "user_move_count": user_move_count,
        "win_rate": _rate(wins, known_count),
        "draw_rate": _rate(draws, known_count),
        "loss_rate": _rate(losses, known_count),
        "average_centipawn_loss": average_cpl,
        "mistakes_per_game": mistakes_per_game,
        "blunders_per_game": blunders_per_game,
        "phase_metrics": phase_out,
        "winning_positions_reached": reached,
        "winning_positions_converted": converted,
        "conversion_rate": _rate(converted, reached),
        "time_pressure_moves_count": tp_moves,
        "time_pressure_mistakes_count": tp_mistakes,
        "time_pressure_error_rate": _rate(tp_mistakes, tp_moves),
        "fast_moves_count": fast_moves,
        "fast_move_mistakes_count": fast_mistakes,
        "fast_move_error_rate": _rate(fast_mistakes, fast_moves),
        "critical_moves_count": critical_moves,
        "critical_accurate_count": critical_accurate,
        "critical_position_accuracy": _rate(critical_accurate, critical_moves),
        "metadata": {
            "known_result_games": known_count,
            "wins": wins,
            "draws": draws,
            "losses": losses,
        },
    }
