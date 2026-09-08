import json
from datetime import datetime, timezone

from worker.weakness_package.handler import run_classification
from worker.weakness_package.repository import PatternRepository
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
            INSERT INTO analysis_events (
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
    assert summary["pattern_occurrences_created"] == 3
    assert summary["pattern_cycles_created"] == 1

    cycle = db_conn.execute(
        "SELECT status, current_occurrences FROM pattern_cycles WHERE user_id = %s",
        (seed["user_id"],),
    ).fetchone()
    assert cycle[0] == 1  # active — 3 occurrences across 3 games
    assert cycle[1] == 3

    event_count = db_conn.execute(
        "SELECT COUNT(*) FROM pattern_occurrences WHERE user_id = %s",
        (seed["user_id"],),
    ).fetchone()[0]
    assert event_count == 3

    occurrence = db_conn.execute(
        """
        SELECT confidence, classifier_version, pattern_taxonomy_version, secondary_pattern
        FROM pattern_occurrences
        WHERE user_id = %s
        LIMIT 1
        """,
        (seed["user_id"],),
    ).fetchone()
    assert float(occurrence[0]) >= 0.65
    assert occurrence[1] == "1.1.0"
    assert occurrence[2] == "1.1.0"
    assert occurrence[3] is None


def test_enqueue_classification_if_needed_dedupes(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    repo = PatternRepository(db_conn)

    assert repo.enqueue_classification_if_needed(seed["user_id"]) is True
    assert repo.enqueue_classification_if_needed(seed["user_id"]) is False

    count = db_conn.execute(
        "SELECT COUNT(*) FROM system_jobs WHERE user_id = %s AND job_type = 2",
        (seed["user_id"],),
    ).fetchone()[0]
    assert count == 1


def _seed_multi_label_game(conn, seed: dict[str, str]) -> str:
    now = datetime.now(timezone.utc)
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
            f"multi-{game_id[-8:]}",
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
            "1.1.0",
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
          id, game_id, ply, move_number, color, san, uci, phase,
          fen_before, fen_after, played_by_user,
          clock_before, clock_after, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            move_id,
            game_id,
            25,
            13,
            0,
            "Qh5",
            "d1h5",
            1,
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            True,
            95,
            94,
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
          mate_before, mate_after, depth, critical_position, metadata,
          created_at, updated_at
        ) VALUES (
          %s, %s, %s, %s,
          %s, %s, %s, %s,
          %s, %s, %s,
          %s, %s, %s, %s, %s::jsonb,
          %s, %s
        )
        """,
        (
            new_id(),
            analysis_run_id,
            game_id,
            move_id,
            40,
            -210,
            250,
            CLASSIFICATION["blunder"],
            "d2d4",
            "d4",
            None,
            None,
            None,
            15,
            False,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO analysis_events (
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
            EVENT_TYPE["material"],
            0.8,
            0.9,
            json.dumps({"material_lost": 3}),
            now,
            now,
        ),
    )
    return move_id


def test_run_classification_persists_multi_label_rows_for_one_move(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    move_id = _seed_multi_label_game(db_conn, seed)

    summary = run_classification(db_conn, seed["user_id"])

    assert summary["games_analyzed"] == 1
    assert summary["pattern_occurrences_created"] >= 2

    rows = db_conn.execute(
        """
        SELECT primary_pattern, secondary_pattern, confidence,
               classifier_version, pattern_taxonomy_version, metadata
        FROM pattern_occurrences
        WHERE user_id = %s AND move_id = %s
        ORDER BY primary_pattern
        """,
        (seed["user_id"], move_id),
    ).fetchall()

    patterns = {int(row[0]) for row in rows}
    from worker.weakness_package.constants import PATTERN

    assert PATTERN["hanging_pieces"] in patterns
    assert PATTERN["moving_too_quickly"] in patterns
    assert all(row[1] is None for row in rows)
    assert all(float(row[2]) >= 0.65 for row in rows)
    assert all(row[3] == "1.1.0" for row in rows)
    assert all(row[4] == "1.1.0" for row in rows)

    for row in rows:
        metadata = row[5]
        if isinstance(metadata, str):
            metadata = json.loads(metadata)
        assert "evidence" in metadata
        assert metadata["evidence"]["detection_reason"]
