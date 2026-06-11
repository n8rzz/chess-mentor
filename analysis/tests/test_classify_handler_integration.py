import json
from datetime import datetime, timezone

from worker.weakness_package.handler import run_classification
from worker.weakness_package.repository import WeaknessRepository
from db_helpers import new_id, seed_import_batch
from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE


def _seed_three_game_pattern(conn, seed: dict[str, str]) -> None:
    now = datetime.now(timezone.utc)
    for index in range(3):
        game_id = new_id()
        analysis_run_id = new_id()
        move_id = new_id()

        conn.execute(
            """
            INSERT INTO games (
              id, user_id, provider_account_id, import_batch_id, provider,
              provider_game_id, pgn, played_at, user_color, result, time_control,
              time_class, metadata, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
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
                1,
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
                2,
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
                150,
                CLASSIFICATION["mistake"],
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
        conn.execute(
            """
            INSERT INTO candidate_events (
              id, analysis_run_id, game_id, move_id,
              event_type, severity, confidence, metadata,
              created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
            """,
            (
                new_id(),
                analysis_run_id,
                game_id,
                move_id,
                EVENT_TYPE["tactical"],
                0.8,
                0.8,
                json.dumps({"missed_tactic": True, "centipawn_loss": 150}),
                now,
                now,
            ),
        )


def test_run_classification_persists_cycles_and_events(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    _seed_three_game_pattern(db_conn, seed)

    summary = run_classification(db_conn, seed["user_id"])

    assert summary["games_analyzed"] == 3
    assert summary["weakness_events_created"] == 3
    assert summary["weakness_cycles_created"] == 1

    cycle = db_conn.execute(
        "SELECT status, current_occurrences FROM weakness_cycles WHERE user_id = %s",
        (seed["user_id"],),
    ).fetchone()
    assert cycle[0] == 1  # active — 3 occurrences across 3 games
    assert cycle[1] == 3

    event_count = db_conn.execute(
        "SELECT COUNT(*) FROM weakness_events WHERE user_id = %s",
        (seed["user_id"],),
    ).fetchone()[0]
    assert event_count == 3


def test_enqueue_classification_if_needed_dedupes(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    repo = WeaknessRepository(db_conn)

    assert repo.enqueue_classification_if_needed(seed["user_id"]) is True
    assert repo.enqueue_classification_if_needed(seed["user_id"]) is False

    count = db_conn.execute(
        "SELECT COUNT(*) FROM system_jobs WHERE user_id = %s AND job_type = 2",
        (seed["user_id"],),
    ).fetchone()[0]
    assert count == 1
