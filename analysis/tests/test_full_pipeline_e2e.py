import json
import os
from datetime import datetime, timezone
from pathlib import Path

import pytest

from worker.eval_package.handler import run_analysis
from worker.training_package.constants import ASSIGNMENTS_PER_DAY, PLAN_DURATION_DAYS
from worker.training_package.handler import run_plan_generation
from worker.weakness_package.constants import PATTERN
from worker.weakness_package.handler import run_classification

from db_helpers import new_id, seed_game_with_analysis_run
from test_training_handler_integration import _seed_puzzles

STOCKFISH_PATH = os.environ.get("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")
stockfish_available = Path(STOCKFISH_PATH).is_file()

pytestmark = pytest.mark.integration


@pytest.mark.skipif(not stockfish_available, reason="Stockfish not available")
def test_full_pipeline_pgn_to_training_plan(db_conn) -> None:
    seed = seed_game_with_analysis_run(db_conn)
    user_id = seed["user_id"]
    game_id = seed["game_id"]
    analysis_run_id = seed["analysis_run_id"]

    analysis_summary = run_analysis(db_conn, analysis_run_id, game_id)
    assert analysis_summary["status"] == "succeeded"
    assert analysis_summary["moves_parsed"] == 17
    assert analysis_summary["user_moves_evaluated"] == 9

    move_count = db_conn.execute(
        "SELECT COUNT(*) FROM moves WHERE game_id = %s",
        (game_id,),
    ).fetchone()[0]
    eval_count = db_conn.execute(
        "SELECT COUNT(*) FROM move_evaluations WHERE analysis_run_id = %s",
        (analysis_run_id,),
    ).fetchone()[0]
    assert move_count == 17
    assert eval_count == 9

    classification_summary = run_classification(db_conn, user_id)
    assert classification_summary["pattern_cycles_created"] >= 0

    cycle_rows = db_conn.execute(
        "SELECT id, pattern FROM pattern_cycles WHERE user_id = %s",
        (user_id,),
    ).fetchall()
    assert cycle_rows, "expected at least one weakness cycle after classification"

    cycle_id, theme = cycle_rows[0]
    _seed_puzzles(db_conn, theme, count=5)

    now = datetime.now(timezone.utc)
    plan_id = new_id()
    db_conn.execute(
        """
        INSERT INTO training_plans (
          id, user_id, pattern_cycle_id, pattern, status,
          baseline_occurrences, current_occurrences, metadata,
          created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            plan_id,
            user_id,
            cycle_id,
            theme,
            1,
            4,
            4,
            json.dumps({}),
            now,
            now,
        ),
    )

    plan_summary = run_plan_generation(db_conn, plan_id)
    expected_assignments = PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY
    assert plan_summary["assignments_created"] == expected_assignments

    assignment_count = db_conn.execute(
        "SELECT COUNT(*) FROM training_assignments WHERE training_plan_id = %s",
        (plan_id,),
    ).fetchone()[0]
    assert assignment_count == expected_assignments

    plan_row = db_conn.execute(
        """
        SELECT starts_at, ends_at, baseline_occurrences
        FROM training_plans
        WHERE id = %s
        """,
        (plan_id,),
    ).fetchone()
    assert plan_row[0] is not None
    assert plan_row[1] is not None
    assert plan_row[2] >= 0

    themes = {row[1] for row in cycle_rows}
    assert themes.intersection(set(PATTERN.values())) == themes
