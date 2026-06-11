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


def test_insert_moves_is_idempotent_when_game_already_has_moves(db_conn):
    seed = seed_game_with_analysis_run(db_conn)
    repo = AnalysisRepository(db_conn)
    positions = generate_positions(DEMO_BLITZ_PGN, user_color=USER_COLOR["white"])

    repo.insert_moves(seed["game_id"], positions)
    repo.insert_moves(seed["game_id"], positions)

    moves = repo.load_moves(seed["game_id"])
    assert len(moves) == 17


def test_insert_move_evaluation_is_idempotent(db_conn):
    seed = seed_game_with_analysis_run(db_conn)
    repo = AnalysisRepository(db_conn)
    positions = generate_positions(DEMO_BLITZ_PGN, user_color=USER_COLOR["white"])
    repo.insert_moves(seed["game_id"], positions)
    move = repo.load_moves(seed["game_id"])[0]

    kwargs = dict(
        analysis_run_id=seed["analysis_run_id"],
        game_id=seed["game_id"],
        move_id=move.id,
        depth=15,
        eval_before_cp=20,
        eval_after_cp=-10,
        centipawn_loss=30,
        classification=1,
        best_move_uci="e2e4",
        best_move_san="e4",
        principal_variation=None,
        mate_before=None,
        mate_after=None,
        metadata={"cpl": 30},
    )
    repo.insert_move_evaluation(**kwargs)
    repo.insert_move_evaluation(**kwargs)

    count = db_conn.execute(
        "SELECT COUNT(*) FROM move_evaluations WHERE analysis_run_id = %s AND move_id = %s",
        (seed["analysis_run_id"], move.id),
    ).fetchone()[0]
    assert count == 1


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
