from datetime import date, datetime, timezone

from worker.training_package.generator import generate_assignments
from worker.training_package.types import PlanRow, PuzzleRow, WeaknessEventRow
from worker.weakness_package.constants import WEAKNESS_THEME


def _inputs():
    plan = PlanRow(
        id="plan-1",
        user_id="user-1",
        weakness_cycle_id="cycle-1",
        theme=WEAKNESS_THEME["hanging_pieces"],
        status=1,
        starts_at=datetime(2026, 6, 1, tzinfo=timezone.utc),
        ends_at=None,
        baseline_occurrences=4,
        current_occurrences=4,
        improvement_threshold=0.30,
        managed_threshold=0.75,
        metadata={},
    )
    events = [
        WeaknessEventRow(
            id="event-a",
            game_id="game-a",
            move_id="move-a",
            created_at=datetime(2026, 5, 20, tzinfo=timezone.utc),
        ),
        WeaknessEventRow(
            id="event-b",
            game_id="game-b",
            move_id="move-b",
            created_at=datetime(2026, 5, 10, tzinfo=timezone.utc),
        ),
    ]
    puzzles = [
        PuzzleRow(id="puzzle-x", theme=WEAKNESS_THEME["hanging_pieces"], rating=900),
        PuzzleRow(id="puzzle-y", theme=WEAKNESS_THEME["hanging_pieces"], rating=1100),
        PuzzleRow(id="puzzle-z", theme=WEAKNESS_THEME["hanging_pieces"], rating=1200),
    ]
    return plan, events, puzzles


def _snapshot(plan, events, puzzles):
    drafts = generate_assignments(plan, events, puzzles, start_date=date(2026, 6, 1))
    return [
        (
            draft.assignment_type,
            draft.due_on.isoformat(),
            draft.puzzle_id,
            draft.source_game_id,
            draft.source_move_id,
            draft.prompt,
        )
        for draft in drafts
    ]


def test_training_generation_is_deterministic():
    plan, events, puzzles = _inputs()

    assert _snapshot(plan, events, puzzles) == _snapshot(plan, events, puzzles)
