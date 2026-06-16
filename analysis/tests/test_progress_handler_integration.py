import json
from datetime import date, datetime, timezone

from worker.jobs import SystemJobRow
from worker.progress_handlers import update_progress_snapshots_handler
from worker.progress_package.constants import (
    JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS,
    SNAPSHOT_KIND_PERFORMANCE,
    SNAPSHOT_KIND_RATING,
    SNAPSHOT_KIND_TRAINING,
    SNAPSHOT_KIND_WEAKNESS,
)
from worker.progress_package.handler import run_snapshot_update
from worker.progress_package.repository import ProgressRepository
from worker.weakness_package.constants import WEAKNESS_THEME
from db_helpers import new_id, seed_import_batch
from worker.eval_package.constants import ANALYSIS_RUN_STATUS, CLASSIFICATION


def _seed_analyzed_game(
    conn,
    seed: dict[str, str],
    *,
    time_class: int = 1,
    user_rating: int = 1520,
    blunder: bool = False,
) -> str:
    now = datetime.now(timezone.utc)
    game_id = new_id()
    analysis_run_id = new_id()
    move_id = new_id()

    conn.execute(
        """
        INSERT INTO games (
          id, user_id, provider_account_id, import_batch_id, provider,
          provider_game_id, pgn, played_at, user_color, result, time_control,
          time_class, user_rating, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            game_id,
            seed["user_id"],
            seed["provider_account_id"],
            seed["import_batch_id"],
            0,
            f"game-{game_id[-8:]}",
            "1. e4 e5",
            now,
            0,
            0,
            "180+0",
            time_class,
            user_rating,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO analysis_runs (
          id, game_id, user_id, status, engine_name, engine_version,
          analysis_version, depth, metadata, created_at, updated_at, finished_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s)
        """,
        (
            analysis_run_id,
            game_id,
            seed["user_id"],
            ANALYSIS_RUN_STATUS["succeeded"],
            "Stockfish",
            "16.1",
            "1.0.0",
            15,
            json.dumps({}),
            now,
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO moves (
          id, game_id, ply, move_number, color, san, uci,
          fen_before, fen_after, played_by_user,
          clock_before, clock_after, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            move_id,
            game_id,
            1,
            1,
            0,
            "e4",
            "e2e4",
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
            True,
            None,
            None,
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO move_evaluations (
          id, analysis_run_id, game_id, move_id,
          eval_before_cp, eval_after_cp, centipawn_loss, classification,
          best_move_uci, best_move_san, principal_variation,
          mate_before, mate_after, depth, metadata,
          created_at, updated_at
        ) VALUES (
          %s, %s, %s, %s,
          %s, %s, %s, %s,
          %s, %s, %s,
          %s, %s, %s, %s::jsonb,
          %s, %s
        )
        """,
        (
            new_id(),
            analysis_run_id,
            game_id,
            move_id,
            20,
            -80,
            350 if blunder else 20,
            CLASSIFICATION["blunder"] if blunder else CLASSIFICATION["good"],
            "d2d4",
            "d4",
            None,
            None,
            None,
            15,
            json.dumps({}),
            now,
            now,
        ),
    )
    return game_id


def _seed_training_plan(conn, seed: dict[str, str], cycle_id: str) -> str:
    now = datetime.now(timezone.utc)
    plan_id = new_id()
    conn.execute(
        """
        INSERT INTO training_plans (
          id, user_id, weakness_cycle_id, theme, status,
          starts_at, ends_at, baseline_occurrences, current_occurrences,
          progress_percentage, improvement_threshold, managed_threshold,
          metadata, created_at, updated_at
        ) VALUES (
          %s, %s, %s, %s, %s,
          %s, %s, %s, %s,
          %s, %s, %s,
          %s::jsonb, %s, %s
        )
        """,
        (
            plan_id,
            seed["user_id"],
            cycle_id,
            WEAKNESS_THEME["missed_tactics"],
            1,
            now,
            now,
            10,
            7,
            30.0,
            0.30,
            0.75,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO training_assignments (
          id, training_plan_id, assignment_type, status, due_on,
          prompt, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            new_id(),
            plan_id,
            1,
            1,
            date.today(),
            "Solve theme puzzle",
            json.dumps({"day_index": 0}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO training_assignments (
          id, training_plan_id, assignment_type, status, due_on,
          prompt, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            new_id(),
            plan_id,
            1,
            0,
            date.today(),
            "Solve theme puzzle",
            json.dumps({"day_index": 0}),
            now,
            now,
        ),
    )
    return plan_id


def test_run_snapshot_update_writes_expected_rows(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    _seed_analyzed_game(db_conn, seed, user_rating=1520, blunder=True)
    now = datetime.now(timezone.utc)
    cycle_id = new_id()
    db_conn.execute(
        """
        INSERT INTO weakness_cycles (
          id, user_id, theme, status, cycle_number,
          baseline_occurrences, current_occurrences,
          baseline_severity, current_severity,
          detection_window_games, detection_window_days,
          started_at, metadata, created_at, updated_at
        ) VALUES (
          %s, %s, %s, %s, %s,
          %s, %s,
          %s, %s,
          %s, %s,
          %s, %s::jsonb, %s, %s
        )
        """,
        (
            cycle_id,
            seed["user_id"],
            WEAKNESS_THEME["missed_tactics"],
            1,
            1,
            10,
            7,
            0.8,
            0.6,
            10,
            30,
            now,
            json.dumps({"frequency": 0.7}),
            now,
            now,
        ),
    )
    plan_id = _seed_training_plan(db_conn, seed, cycle_id)

    summary = run_snapshot_update(db_conn, seed["user_id"])

    assert summary["snapshots_created"] >= 4
    assert SNAPSHOT_KIND_RATING in summary["kinds"]
    assert SNAPSHOT_KIND_PERFORMANCE in summary["kinds"]
    assert SNAPSHOT_KIND_WEAKNESS in summary["kinds"]
    assert SNAPSHOT_KIND_TRAINING in summary["kinds"]

    rating_row = db_conn.execute(
        """
        SELECT rating, metadata
        FROM progress_snapshots
        WHERE user_id = %s AND metadata->>'kind' = %s
        """,
        (seed["user_id"], SNAPSHOT_KIND_RATING),
    ).fetchone()
    assert rating_row[0] == 1520

    performance_row = db_conn.execute(
        """
        SELECT blunders_per_game, games_analyzed_count, metadata
        FROM progress_snapshots
        WHERE user_id = %s AND metadata->>'kind' = %s
        """,
        (seed["user_id"], SNAPSHOT_KIND_PERFORMANCE),
    ).fetchone()
    assert performance_row[1] == 1
    assert float(performance_row[0]) == 1.0

    training_row = db_conn.execute(
        """
        SELECT training_plan_id, metadata
        FROM progress_snapshots
        WHERE user_id = %s AND metadata->>'kind' = %s
        """,
        (seed["user_id"], SNAPSHOT_KIND_TRAINING),
    ).fetchone()
    assert training_row[0] == plan_id
    training_metadata = training_row[1]
    assert training_metadata["plan_progress_percentage"] == 30.0
    assert training_metadata["training_completion_percentage"] == 50.0


def test_enqueue_snapshots_if_needed_dedupes(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    repo = ProgressRepository(db_conn)

    assert repo.enqueue_snapshots_if_needed(seed["user_id"]) is True
    assert repo.enqueue_snapshots_if_needed(seed["user_id"]) is False

    count = db_conn.execute(
        "SELECT COUNT(*) FROM system_jobs WHERE user_id = %s AND job_type = %s",
        (seed["user_id"], JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS),
    ).fetchone()[0]
    assert count == 1


def test_update_progress_snapshots_handler(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    _seed_analyzed_game(db_conn, seed, user_rating=1600)
    db_conn.commit()

    job = SystemJobRow(
        id=new_id(),
        user_id=seed["user_id"],
        job_type=JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS,
        payload={},
    )

    result = update_progress_snapshots_handler(job)

    assert result["snapshots_created"] >= 1
    count = db_conn.execute(
        "SELECT COUNT(*) FROM progress_snapshots WHERE user_id = %s",
        (seed["user_id"],),
    ).fetchone()[0]
    assert count >= 1
