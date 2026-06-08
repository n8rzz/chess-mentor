from worker.eval_package.constants import ANALYSIS_RUN_STATUS, USER_COLOR
from worker.eval_package.positions import generate_positions
from worker.eval_package.repository import AnalysisRepository
from db_helpers import DEMO_BLITZ_PGN, seed_game_with_analysis_run


def test_repository_inserts_and_loads_moves(db_conn):
    seed = seed_game_with_analysis_run(db_conn)
    repo = AnalysisRepository(db_conn)
    positions = generate_positions(DEMO_BLITZ_PGN, user_color=USER_COLOR["white"])

    repo.insert_moves(seed["game_id"], positions)
    moves = repo.load_moves(seed["game_id"])

    assert len(moves) == 17
    assert moves[0].san == "e4"


def test_repository_marks_analysis_run_succeeded(db_conn):
    seed = seed_game_with_analysis_run(db_conn)
    repo = AnalysisRepository(db_conn)

    repo.mark_running(seed["analysis_run_id"])
    repo.mark_succeeded(seed["analysis_run_id"], metadata_patch={"moves_parsed": 17})

    row = db_conn.execute(
        "SELECT status, metadata FROM analysis_runs WHERE id = %s",
        (seed["analysis_run_id"],),
    ).fetchone()
    assert row[0] == ANALYSIS_RUN_STATUS["succeeded"]
    assert row[1]["moves_parsed"] == 17
