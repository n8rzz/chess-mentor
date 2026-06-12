from __future__ import annotations

from datetime import date, timedelta

from worker.training_package.constants import (
    ASSIGNMENT_TYPE,
    DAILY_HABIT_EXERCISES,
    DAILY_PERSONAL_REVIEWS,
    DAILY_PLAY_GAMES,
    DAILY_THEME_PUZZLES,
    DEFAULT_HABIT_PROMPT,
    HABIT_PROMPTS,
    PERSONAL_REVIEW_PROMPT,
    PLAN_DURATION_DAYS,
    PLAY_GAME_PROMPT,
    THEME_BY_INTEGER,
    THEME_LABELS,
)
from worker.training_package.types import AssignmentDraft, PlanRow, PuzzleRow, WeaknessEventRow


def generate_assignments(
    plan: PlanRow,
    events: list[WeaknessEventRow],
    puzzles: list[PuzzleRow],
    *,
    start_day_offset: int = 0,
    day_count: int = PLAN_DURATION_DAYS,
    start_date: date,
) -> list[AssignmentDraft]:
    theme_key = THEME_BY_INTEGER[plan.theme]
    theme_label = THEME_LABELS[plan.theme]
    habit_prompt = HABIT_PROMPTS.get(theme_key, DEFAULT_HABIT_PROMPT)
    play_prompt = PLAY_GAME_PROMPT.format(theme_label=theme_label)

    sorted_events = sorted(events, key=lambda event: (event.created_at, event.id), reverse=True)
    sorted_puzzles = sorted(puzzles, key=lambda puzzle: (puzzle.rating or 0, puzzle.id))

    drafts: list[AssignmentDraft] = []

    for day_index in range(day_count):
        due_on = start_date + timedelta(days=start_day_offset + day_index)

        for review_index in range(DAILY_PERSONAL_REVIEWS):
            event = _pick(sorted_events, day_index * DAILY_PERSONAL_REVIEWS + review_index)
            drafts.append(
                AssignmentDraft(
                    assignment_type=ASSIGNMENT_TYPE["personal_position_review"],
                    due_on=due_on,
                    source_game_id=event.game_id if event else None,
                    source_move_id=event.move_id if event else None,
                    prompt=PERSONAL_REVIEW_PROMPT,
                    metadata={"day_index": start_day_offset + day_index},
                )
            )

        for puzzle_index in range(DAILY_THEME_PUZZLES):
            puzzle = _pick(sorted_puzzles, day_index * DAILY_THEME_PUZZLES + puzzle_index)
            drafts.append(
                AssignmentDraft(
                    assignment_type=ASSIGNMENT_TYPE["theme_puzzle"],
                    due_on=due_on,
                    puzzle_id=puzzle.id if puzzle else None,
                    metadata={"day_index": start_day_offset + day_index, "slot": puzzle_index},
                )
            )

        for _ in range(DAILY_PLAY_GAMES):
            drafts.append(
                AssignmentDraft(
                    assignment_type=ASSIGNMENT_TYPE["play_game"],
                    due_on=due_on,
                    prompt=play_prompt,
                    metadata={"day_index": start_day_offset + day_index},
                )
            )

        for _ in range(DAILY_HABIT_EXERCISES):
            drafts.append(
                AssignmentDraft(
                    assignment_type=ASSIGNMENT_TYPE["habit_exercise"],
                    due_on=due_on,
                    prompt=habit_prompt,
                    metadata={"day_index": start_day_offset + day_index, "theme": theme_key},
                )
            )

    return drafts


def _pick(items: list, index: int):
    if not items:
        return None
    return items[index % len(items)]
