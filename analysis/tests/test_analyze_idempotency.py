import os
from pathlib import Path

import pytest

from worker.eval_package.constants import ANALYSIS_RUN_STATUS
from worker.eval_package.handler import run_analysis
from worker.eval_package.repository import AnalysisRepository
from db_helpers import seed_game_with_analysis_run, seed_partial_analysis_state

STOCKFISH_PATH = os.environ.get("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")
stockfish_available = Path(STOCKFISH_PATH).is_file()


def test_run_analysis_returns_early_when_already_succeeded(db_conn):
    seed = seed_game_with_analysis_run(db_conn)
    repo = AnalysisRepository(db_conn)
    repo.mark_running(seed["analysis_run_id"])
    repo.mark_succeeded(
        seed["analysis_run_id"],
        metadata_patch={
            "moves_parsed": 17,
            "user_moves_evaluated": 9,
            "events_detected": 4,
        },
    )

    summary = run_analysis(db_conn, seed["analysis_run_id"], seed["game_id"])

    assert summary["status"] == "succeeded"
    assert summary["moves_parsed"] == 17
    assert summary["user_moves_evaluated"] == 9
    assert summary["events_detected"] == 4

    move_count = db_conn.execute(
        "SELECT COUNT(*) FROM moves WHERE game_id = %s",
        (seed["game_id"],),
    ).fetchone()[0]
    assert move_count == 0


def test_repository_load_and_query_helpers(db_conn):
    partial = seed_partial_analysis_state(db_conn, evaluated_user_move_count=2)
    repo = AnalysisRepository(db_conn)

    assert repo.analysis_run_status(partial["analysis_run_id"]) == ANALYSIS_RUN_STATUS["running"]

    moves = repo.load_moves(partial["game_id"])
    user_move = next(move for move in moves if move.played_by_user)
    assert repo.has_move_evaluation(partial["analysis_run_id"], user_move.id)

    loaded = repo.load_move_evaluation(partial["analysis_run_id"], user_move.id)
    assert loaded is not None
    assert loaded[1] == 20

    assert repo.move_has_candidate_events(partial["analysis_run_id"], user_move.id)
    assert repo.count_candidate_events(partial["analysis_run_id"]) == 2


@pytest.mark.skipif(not stockfish_available, reason="Stockfish binary not available")
def test_run_analysis_resumes_partial_run_without_duplicates(db_conn):
    partial = seed_partial_analysis_state(db_conn, evaluated_user_move_count=2)
    analysis_run_id = partial["analysis_run_id"]
    game_id = partial["game_id"]

    summary = run_analysis(db_conn, analysis_run_id, game_id)

    assert summary["status"] == "succeeded"
    assert summary["user_moves_evaluated"] == partial["user_move_count"]

    eval_count = db_conn.execute(
        "SELECT COUNT(*) FROM move_evaluations WHERE analysis_run_id = %s",
        (analysis_run_id,),
    ).fetchone()[0]
    assert eval_count == partial["user_move_count"]

    duplicate_evals = db_conn.execute(
        """
        SELECT move_id, COUNT(*) AS row_count
        FROM move_evaluations
        WHERE analysis_run_id = %s
        GROUP BY move_id
        HAVING COUNT(*) > 1
        """,
        (analysis_run_id,),
    ).fetchall()
    assert duplicate_evals == []

    run = db_conn.execute(
        "SELECT status FROM analysis_runs WHERE id = %s",
        (analysis_run_id,),
    ).fetchone()
    assert run[0] == ANALYSIS_RUN_STATUS["succeeded"]


@pytest.mark.skipif(not stockfish_available, reason="Stockfish binary not available")
def test_run_analysis_second_call_returns_cached_summary(db_conn):
    seed = seed_game_with_analysis_run(db_conn)
    first = run_analysis(db_conn, seed["analysis_run_id"], seed["game_id"])
    second = run_analysis(db_conn, seed["analysis_run_id"], seed["game_id"])

    assert first["status"] == "succeeded"
    assert second["status"] == "succeeded"
    assert second["user_moves_evaluated"] == first["user_moves_evaluated"]
    assert second["events_detected"] == first["events_detected"]

    eval_count = db_conn.execute(
        "SELECT COUNT(*) FROM move_evaluations WHERE analysis_run_id = %s",
        (seed["analysis_run_id"],),
    ).fetchone()[0]
    assert eval_count == first["user_moves_evaluated"]
