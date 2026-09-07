import json
from datetime import datetime, timezone

from worker.eval_package.constants import ANALYSIS_RUN_STATUS, CLASSIFICATION
from worker.eval_package.game_phase import GAME_PHASE
from worker.jobs import SystemJobRow
from worker.metrics_handlers import refresh_review_period_metrics_handler
from worker.metrics_package.constants import (
    JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS,
    METRIC_FORMULA_VERSION,
)
from worker.metrics_package.repository import MetricsRepository, persist_game_metrics
from db_helpers import new_id, seed_import_batch


def _seed_analyzed_game_for_metrics(conn, seed: dict[str, str], *, result: int = 0) -> dict[str, str]:
    now = datetime.now(timezone.utc)
    game_id = new_id()
    analysis_run_id = new_id()
    move_a = new_id()
    move_b = new_id()

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
            result,
            "180+2",
            1,
            1500,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO analysis_runs (
          id, game_id, user_id, status, engine_name, engine_version,
          analysis_version, metric_formula_version, depth, metadata,
          created_at, updated_at, finished_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s)
        """,
        (
            analysis_run_id,
            game_id,
            seed["user_id"],
            ANALYSIS_RUN_STATUS["succeeded"],
            "Stockfish",
            "16.1",
            "1.1.0",
            METRIC_FORMULA_VERSION,
            14,
            json.dumps({}),
            now,
            now,
            now,
        ),
    )

    for move_id, ply, phase, before, after, cpl, classification, clock_before, clock_after in [
        (move_a, 1, GAME_PHASE["middlegame"], 220, 210, 10, CLASSIFICATION["good"], 90, 88),
        (move_b, 3, GAME_PHASE["middlegame"], 230, 200, 30, CLASSIFICATION["good"], 88, 86),
    ]:
        conn.execute(
            """
            INSERT INTO moves (
              id, game_id, ply, move_number, color, san, uci,
              fen_before, fen_after, played_by_user, phase,
              clock_before, clock_after, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                move_id,
                game_id,
                ply,
                (ply + 1) // 2,
                0,
                "e4",
                "e2e4",
                "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
                True,
                phase,
                clock_before,
                clock_after,
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
                before,
                after,
                cpl,
                classification,
                "d2d4",
                "d4",
                None,
                None,
                None,
                14,
                False,
                json.dumps({}),
                now,
                now,
            ),
        )

    return {
        "game_id": game_id,
        "analysis_run_id": analysis_run_id,
        "user_id": seed["user_id"],
    }


def test_persist_game_metrics_upserts_row(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    game = _seed_analyzed_game_for_metrics(db_conn, seed, result=0)
    db_conn.commit()

    summary = persist_game_metrics(db_conn, game["analysis_run_id"])
    db_conn.commit()

    assert summary is not None
    assert summary["user_move_count"] == 2

    row = db_conn.execute(
        """
        SELECT average_centipawn_loss, winning_positions_reached, winning_positions_converted,
               metric_formula_version
        FROM game_metrics
        WHERE analysis_run_id = %s
        """,
        (game["analysis_run_id"],),
    ).fetchone()
    assert row is not None
    assert float(row[0]) == 20.0
    assert row[1] == 1
    assert row[2] == 1
    assert row[3] == METRIC_FORMULA_VERSION

    # Upsert is idempotent
    persist_game_metrics(db_conn, game["analysis_run_id"])
    db_conn.commit()
    count = db_conn.execute(
        "SELECT COUNT(*) FROM game_metrics WHERE analysis_run_id = %s",
        (game["analysis_run_id"],),
    ).fetchone()[0]
    assert count == 1


def test_refresh_review_period_metrics_handler(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    game = _seed_analyzed_game_for_metrics(db_conn, seed, result=0)
    persist_game_metrics(db_conn, game["analysis_run_id"])

    now = datetime.now(timezone.utc)
    period_id = new_id()
    db_conn.execute(
        """
        INSERT INTO review_periods (
          id, user_id, label, starts_at, ends_at, status, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (period_id, seed["user_id"], "Last games", now, now, 1, json.dumps({}), now, now),
    )
    db_conn.execute(
        """
        INSERT INTO review_period_games (
          id, review_period_id, game_id, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s)
        """,
        (new_id(), period_id, game["game_id"], now, now),
    )
    db_conn.commit()

    result = refresh_review_period_metrics_handler(
        SystemJobRow(
            id=new_id(),
            user_id=seed["user_id"],
            job_type=JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS,
            payload={},
        )
    )

    assert result["periods_refreshed"] == 1
    row = db_conn.execute(
        """
        SELECT win_rate, analyzed_games_count, conversion_rate, average_centipawn_loss
        FROM review_period_metrics
        WHERE review_period_id = %s AND metric_formula_version = %s
        """,
        (period_id, METRIC_FORMULA_VERSION),
    ).fetchone()
    assert row is not None
    assert float(row[0]) == 1.0
    assert row[1] == 1
    assert float(row[2]) == 1.0
    assert float(row[3]) == 20.0


def test_enqueue_period_refresh_dedupes(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    repo = MetricsRepository(db_conn)
    assert repo.enqueue_period_refresh_if_needed(seed["user_id"]) is True
    assert repo.enqueue_period_refresh_if_needed(seed["user_id"]) is False
    count = db_conn.execute(
        "SELECT COUNT(*) FROM system_jobs WHERE user_id = %s AND job_type = %s",
        (seed["user_id"], JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS),
    ).fetchone()[0]
    assert count == 1


def test_refresh_skips_archived_periods(db_conn):
    seed = seed_import_batch(db_conn, batch_status=2)
    game = _seed_analyzed_game_for_metrics(db_conn, seed, result=0)
    persist_game_metrics(db_conn, game["analysis_run_id"])

    now = datetime.now(timezone.utc)
    active_id = new_id()
    archived_id = new_id()
    for period_id, status in [(active_id, 1), (archived_id, 3)]:
        db_conn.execute(
            """
            INSERT INTO review_periods (
              id, user_id, label, starts_at, ends_at, status, metadata, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
            """,
            (period_id, seed["user_id"], f"period-{status}", now, now, status, json.dumps({}), now, now),
        )
        db_conn.execute(
            """
            INSERT INTO review_period_games (
              id, review_period_id, game_id, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s)
            """,
            (new_id(), period_id, game["game_id"], now, now),
        )
    db_conn.commit()

    result = refresh_review_period_metrics_handler(
        SystemJobRow(
            id=new_id(),
            user_id=seed["user_id"],
            job_type=JOB_TYPE_REFRESH_REVIEW_PERIOD_METRICS,
            payload={},
        )
    )
    assert result["periods_refreshed"] == 1

    active_count = db_conn.execute(
        "SELECT COUNT(*) FROM review_period_metrics WHERE review_period_id = %s",
        (active_id,),
    ).fetchone()[0]
    archived_count = db_conn.execute(
        "SELECT COUNT(*) FROM review_period_metrics WHERE review_period_id = %s",
        (archived_id,),
    ).fetchone()[0]
    assert active_count == 1
    assert archived_count == 0
