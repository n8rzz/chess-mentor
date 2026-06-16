from __future__ import annotations

from decimal import Decimal
from typing import Any


def compute_plan_progress_percentage(baseline_occurrences: int, current_occurrences: int) -> float:
    if baseline_occurrences <= 0:
        return 0.0

    reduction = (baseline_occurrences - current_occurrences) / baseline_occurrences
    return round(max(reduction * 100.0, 0.0), 2)


def compute_training_completion_percentage(completed_count: int, due_through_today: int) -> float | None:
    if due_through_today <= 0:
        return None

    return round((completed_count / due_through_today) * 100.0, 2)


def compute_weakness_frequency(current_occurrences: int, detection_window_games: int | None, metadata: dict[str, Any]) -> float:
    stored = metadata.get("frequency")
    if stored is not None:
        return round(float(stored), 4)

    if not detection_window_games:
        return 0.0

    return round(current_occurrences / detection_window_games, 4)


def compute_blunders_per_game(blunder_count: int, analyzed_game_count: int) -> Decimal | None:
    if analyzed_game_count <= 0:
        return None

    return Decimal(blunder_count) / Decimal(analyzed_game_count)
