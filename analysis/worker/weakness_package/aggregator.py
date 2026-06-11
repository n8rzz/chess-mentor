from __future__ import annotations

import math
from datetime import datetime, timezone

from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE
from worker.weakness_package.constants import (
    RECENCY_HALF_LIFE_DAYS,
    SEVERITY_WEIGHTS,
    TIME_PRESSURE_MISTAKE_RATE_MULTIPLIER,
    TIME_PRESSURE_MIN_MISTAKES,
)
from worker.weakness_package.cycles import build_cycle
from worker.weakness_package.theme_rules import classify_move, classify_time_pressure_standalone
from worker.weakness_package.types import ClassifiedWeakness, CycleBuildResult, MoveArtifact, ThemeAggregation


def classify_artifacts(artifacts: list[MoveArtifact]) -> list[ClassifiedWeakness]:
    classified: list[ClassifiedWeakness] = []
    seen_moves: set[str] = set()

    for artifact in artifacts:
        weakness = classify_move(artifact)
        if weakness is not None and artifact.move_id not in seen_moves:
            classified.append(weakness)
            seen_moves.add(artifact.move_id)

    baseline_rate, pressure_rate = _time_pressure_mistake_rates(artifacts)
    if _standalone_time_pressure_qualifies(artifacts, baseline_rate, pressure_rate):
        for artifact in artifacts:
            if artifact.move_id in seen_moves:
                continue
            weakness = classify_time_pressure_standalone(
                artifact,
                baseline_mistake_rate=baseline_rate,
                pressure_mistake_rate=pressure_rate,
            )
            if weakness is not None:
                classified.append(weakness)
                seen_moves.add(artifact.move_id)

    return dedupe_by_game_and_theme(classified)


def dedupe_by_game_and_theme(classified: list[ClassifiedWeakness]) -> list[ClassifiedWeakness]:
    """Keep one weakness event per game per theme (highest severity).

    Recurring weaknesses are patterns across games, not per-move noise. Without
    this, detectors like opening delayed-castling fire on many plies in the same game.
    """
    best_by_key: dict[tuple[str, int], ClassifiedWeakness] = {}
    for event in classified:
        key = (event.game_id, event.primary_theme)
        existing = best_by_key.get(key)
        if existing is None or event.severity > existing.severity:
            best_by_key[key] = event
    return sorted(best_by_key.values(), key=lambda item: item.played_at)


def aggregate_by_theme(
    classified: list[ClassifiedWeakness],
    *,
    games_analyzed: int,
    reference_time: datetime | None = None,
) -> list[ThemeAggregation]:
    grouped: dict[int, ThemeAggregation] = {}
    for event in classified:
        bucket = grouped.setdefault(event.primary_theme, ThemeAggregation(theme=event.primary_theme))
        bucket.events.append(event)

    for aggregation in grouped.values():
        aggregation.events.sort(key=lambda item: item.played_at)

    return sorted(grouped.values(), key=lambda item: item.theme)


def build_cycles(
    aggregations: list[ThemeAggregation],
    *,
    games_analyzed: int,
    archived_cycle_numbers: dict[int, int],
    reference_time: datetime | None = None,
) -> list[CycleBuildResult]:
    now = reference_time or datetime.now(timezone.utc)
    results: list[CycleBuildResult] = []

    for aggregation in aggregations:
        if aggregation.occurrences == 0:
            continue

        frequency = aggregation.games_with_occurrences / max(games_analyzed, 1)
        severity = compute_cycle_severity(aggregation, games_analyzed=games_analyzed, reference_time=now)
        prior_cycle = archived_cycle_numbers.get(aggregation.theme, 0)
        cycle_number = prior_cycle + 1 if prior_cycle else 1

        results.append(
            build_cycle(
                aggregation=aggregation,
                games_analyzed=games_analyzed,
                frequency=frequency,
                severity=severity,
                cycle_number=cycle_number,
            )
        )

    return results


def compute_cycle_severity(
    aggregation: ThemeAggregation,
    *,
    games_analyzed: int,
    reference_time: datetime,
) -> float:
    if aggregation.occurrences == 0:
        return 0.0

    frequency = aggregation.games_with_occurrences / max(games_analyzed, 1)
    occurrence_score = min(1.0, frequency * 2.0)

    impact_score = sum(event.severity for event in aggregation.events) / aggregation.occurrences

    recency_weights = [
        _recency_weight(event.played_at, reference_time) for event in aggregation.events
    ]
    total_weight = sum(recency_weights) or 1.0
    recency_score = sum(
        weight * event.severity for weight, event in zip(recency_weights, aggregation.events)
    ) / total_weight

    combined = (
        SEVERITY_WEIGHTS["occurrence"] * occurrence_score
        + SEVERITY_WEIGHTS["impact"] * impact_score
        + SEVERITY_WEIGHTS["recency"] * recency_score
    )
    return round(min(1.0, max(0.0, combined)), 2)


def _recency_weight(played_at: datetime, reference_time: datetime) -> float:
    if played_at.tzinfo is None:
        played_at = played_at.replace(tzinfo=timezone.utc)
    age_days = max((reference_time - played_at).total_seconds() / 86_400.0, 0.0)
    return math.pow(0.5, age_days / RECENCY_HALF_LIFE_DAYS)


def _time_pressure_mistake_rates(artifacts: list[MoveArtifact]) -> tuple[float, float]:
    total_user_moves = 0
    total_mistakes = 0
    pressure_moves = 0
    pressure_mistakes = 0

    for artifact in artifacts:
        if artifact.evaluation is None:
            continue

        total_user_moves += 1
        is_mistake = artifact.evaluation.classification >= CLASSIFICATION["mistake"]
        if is_mistake:
            total_mistakes += 1

        under_pressure = any(
            event.event_type == EVENT_TYPE["time_pressure"] for event in artifact.candidate_events
        )
        if under_pressure:
            pressure_moves += 1
            if is_mistake:
                pressure_mistakes += 1

    baseline = total_mistakes / max(total_user_moves, 1)
    pressure = pressure_mistakes / max(pressure_moves, 1)
    return baseline, pressure


def _standalone_time_pressure_qualifies(
    artifacts: list[MoveArtifact],
    baseline_rate: float,
    pressure_rate: float,
) -> bool:
    if baseline_rate <= 0:
        return False

    pressure_mistakes = 0
    for artifact in artifacts:
        under_pressure = any(
            event.event_type == EVENT_TYPE["time_pressure"] for event in artifact.candidate_events
        )
        if not under_pressure or artifact.evaluation is None:
            continue
        if artifact.evaluation.classification >= CLASSIFICATION["mistake"]:
            pressure_mistakes += 1

    return (
        pressure_mistakes >= TIME_PRESSURE_MIN_MISTAKES
        and pressure_rate >= baseline_rate * TIME_PRESSURE_MISTAKE_RATE_MULTIPLIER
    )


def detection_window_config() -> tuple[int, int]:
    return DETECTION_WINDOW_GAMES, DETECTION_WINDOW_DAYS
