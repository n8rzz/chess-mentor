import os
from pathlib import Path

import pytest

from worker.eval_package.constants import ANALYSIS_RUN_STATUS
from worker.eval_package.handler import run_analysis
from db_helpers import seed_game_with_analysis_run

STOCKFISH_PATH = os.environ.get("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")
stockfish_available = Path(STOCKFISH_PATH).is_file()


@pytest.mark.skipif(not stockfish_available, reason="Stockfish binary not available")
def test_run_analysis_persists_moves_evaluations_and_events(db_conn):
    seed = seed_game_with_analysis_run(db_conn)

    summary = run_analysis(db_conn, seed["analysis_run_id"], seed["game_id"])

    assert summary["moves_parsed"] == 17
    assert summary["user_moves_evaluated"] == 9
    assert summary["events_detected"] >= 0

    run = db_conn.execute(
        "SELECT status FROM analysis_runs WHERE id = %s",
        (seed["analysis_run_id"],),
    ).fetchone()
    assert run[0] == ANALYSIS_RUN_STATUS["succeeded"]

    move_count = db_conn.execute(
        "SELECT COUNT(*) FROM moves WHERE game_id = %s",
        (seed["game_id"],),
    ).fetchone()[0]
    eval_count = db_conn.execute(
        "SELECT COUNT(*) FROM move_evaluations WHERE analysis_run_id = %s",
        (seed["analysis_run_id"],),
    ).fetchone()[0]

    assert move_count == 17
    assert eval_count == 9


@pytest.mark.skipif(not stockfish_available, reason="Stockfish binary not available")
def test_run_analysis_is_deterministic_for_eval_metrics(db_conn):
    seed_a = seed_game_with_analysis_run(db_conn)
    run_analysis(db_conn, seed_a["analysis_run_id"], seed_a["game_id"])
    metrics_a = db_conn.execute(
        """
        SELECT me.centipawn_loss, me.classification
        FROM move_evaluations me
        JOIN moves m ON m.id = me.move_id
        WHERE me.analysis_run_id = %s
        ORDER BY m.ply
        """,
        (seed_a["analysis_run_id"],),
    ).fetchall()

    seed_b = seed_game_with_analysis_run(db_conn)
    run_analysis(db_conn, seed_b["analysis_run_id"], seed_b["game_id"])
    metrics_b = db_conn.execute(
        """
        SELECT me.centipawn_loss, me.classification
        FROM move_evaluations me
        JOIN moves m ON m.id = me.move_id
        WHERE me.analysis_run_id = %s
        ORDER BY m.ply
        """,
        (seed_b["analysis_run_id"],),
    ).fetchall()

    assert metrics_a == metrics_b
