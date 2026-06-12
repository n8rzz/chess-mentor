from datetime import date, datetime, timezone

from worker.training_package.constants import (
    ASSIGNMENTS_PER_DAY,
    ASSIGNMENT_TYPE,
    DAILY_HABIT_EXERCISES,
    DAILY_PERSONAL_REVIEWS,
    DAILY_PLAY_GAMES,
    DAILY_THEME_PUZZLES,
    IMPROVING_THRESHOLD,
    MANAGED_THRESHOLD,
    PLAN_DURATION_DAYS,
)
from worker.training_package.generator import generate_assignments
from worker.training_package.types import PlanRow, PuzzleRow, WeaknessEventRow
from worker.weakness_package.constants import WEAKNESS_THEME


def _plan(theme: str = "missed_tactics") -> PlanRow:
    return PlanRow(
        id="plan-1",
        user_id="user-1",
        weakness_cycle_id="cycle-1",
        theme=WEAKNESS_THEME[theme],
        status=1,
        starts_at=datetime(2026, 6, 1, tzinfo=timezone.utc),
        ends_at=None,
        baseline_occurrences=5,
        current_occurrences=5,
        improvement_threshold=IMPROVING_THRESHOLD,
        managed_threshold=MANAGED_THRESHOLD,
        metadata={},
    )


def _events(count: int = 3) -> list[WeaknessEventRow]:
    return [
        WeaknessEventRow(
            id=f"event-{index}",
            game_id=f"game-{index}",
            move_id=f"move-{index}",
            created_at=datetime(2026, 6, 1, index, tzinfo=timezone.utc),
        )
        for index in range(count)
    ]


def _puzzles(count: int = 5) -> list[PuzzleRow]:
    return [
        PuzzleRow(id=f"puzzle-{index}", theme=WEAKNESS_THEME["missed_tactics"], rating=1000 + index * 50)
        for index in range(count)
    ]


def test_generate_assignments_daily_counts():
    drafts = generate_assignments(
        _plan(),
        _events(),
        _puzzles(),
        start_date=date(2026, 6, 1),
    )

    assert len(drafts) == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY

    by_day: dict[date, dict[int, int]] = {}
    for draft in drafts:
        by_day.setdefault(draft.due_on, {})
        by_day[draft.due_on][draft.assignment_type] = by_day[draft.due_on].get(draft.assignment_type, 0) + 1

    assert len(by_day) == PLAN_DURATION_DAYS
    for counts in by_day.values():
        assert counts[ASSIGNMENT_TYPE["personal_position_review"]] == DAILY_PERSONAL_REVIEWS
        assert counts[ASSIGNMENT_TYPE["theme_puzzle"]] == DAILY_THEME_PUZZLES
        assert counts[ASSIGNMENT_TYPE["play_game"]] == DAILY_PLAY_GAMES
        assert counts[ASSIGNMENT_TYPE["habit_exercise"]] == DAILY_HABIT_EXERCISES


def test_generate_assignments_theme_habit_prompt():
    drafts = generate_assignments(
        _plan("king_safety"),
        _events(),
        _puzzles(),
        start_date=date(2026, 6, 1),
    )

    habit = next(draft for draft in drafts if draft.assignment_type == ASSIGNMENT_TYPE["habit_exercise"])
    assert "king safe" in habit.prompt.lower()


def test_generate_assignments_cycles_puzzles_and_events():
    drafts = generate_assignments(
        _plan(),
        _events(count=2),
        _puzzles(count=3),
        start_date=date(2026, 6, 1),
    )

    day_zero_puzzles = [
        draft.puzzle_id
        for draft in drafts
        if draft.due_on == date(2026, 6, 1) and draft.assignment_type == ASSIGNMENT_TYPE["theme_puzzle"]
    ]
    day_one_puzzles = [
        draft.puzzle_id
        for draft in drafts
        if draft.due_on == date(2026, 6, 2) and draft.assignment_type == ASSIGNMENT_TYPE["theme_puzzle"]
    ]

    assert day_zero_puzzles == ["puzzle-0", "puzzle-1", "puzzle-2", "puzzle-0", "puzzle-1"]
    assert day_one_puzzles == ["puzzle-2", "puzzle-0", "puzzle-1", "puzzle-2", "puzzle-0"]

    day_zero_review = next(
        draft
        for draft in drafts
        if draft.due_on == date(2026, 6, 1)
        and draft.assignment_type == ASSIGNMENT_TYPE["personal_position_review"]
    )
    day_one_review = next(
        draft
        for draft in drafts
        if draft.due_on == date(2026, 6, 2)
        and draft.assignment_type == ASSIGNMENT_TYPE["personal_position_review"]
    )

    assert day_zero_review.source_move_id == "move-1"
    assert day_one_review.source_move_id == "move-0"


def test_generate_assignments_play_game_prompt_includes_theme_label():
    drafts = generate_assignments(
        _plan("king_safety"),
        _events(),
        _puzzles(),
        start_date=date(2026, 6, 1),
    )

    play = next(draft for draft in drafts if draft.assignment_type == ASSIGNMENT_TYPE["play_game"])
    assert "King Safety" in play.prompt


def test_generate_assignments_habit_prompt_falls_back_to_default(monkeypatch):
    from worker.training_package import generator as generator_module

    monkeypatch.setattr(generator_module, "HABIT_PROMPTS", {})

    drafts = generate_assignments(
        _plan("missed_tactics"),
        _events(),
        _puzzles(),
        start_date=date(2026, 6, 1),
    )

    habit = next(draft for draft in drafts if draft.assignment_type == ASSIGNMENT_TYPE["habit_exercise"])
    assert habit.prompt == "Before every move ask: What is the best candidate move?"
