import json
from datetime import datetime, timezone

from worker.jobs import SystemJobRow
from worker.training_handlers import generate_training_plan_handler
from worker.training_package.constants import ASSIGNMENTS_PER_DAY, PLAN_DURATION_DAYS
from worker.training_package.handler import run_plan_generation
from worker.weakness_package.constants import WEAKNESS_THEME
from db_helpers import new_id, seed_import_batch


def _seed_puzzles(conn, theme: int, count: int = 5) -> list[str]:
    now = datetime.now(timezone.utc)
    puzzle_ids = []
    for index in range(count):
        puzzle_id = new_id()
        puzzle_ids.append(puzzle_id)
        conn.execute(
            """
            INSERT INTO puzzles (
              id, source, fen, solution, theme, motif, rating, difficulty, metadata,
              created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
            """,
            (
                puzzle_id,
                0,
                "6k1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1",
                "f1f8",
                theme,
                0,
                1000 + index * 50,
                0,
                json.dumps({"seed_key": f"test_{theme}_{index}"}),
                now,
                now,
            ),
        )
    return puzzle_ids


def _seed_training_plan(conn) -> dict[str, str]:
    seed = seed_import_batch(conn, batch_status=2)
    now = datetime.now(timezone.utc)
    cycle_id = new_id()
    plan_id = new_id()
    game_id = new_id()
    move_id = new_id()
    theme = WEAKNESS_THEME["missed_tactics"]

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
            theme,
            1,
            1,
            4,
            4,
            0.8,
            0.8,
            30,
            30,
            now,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO weakness_events (
          id, user_id, weakness_cycle_id, game_id, move_id,
          primary_theme, phase, severity, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            new_id(),
            seed["user_id"],
            cycle_id,
            game_id,
            move_id,
            theme,
            1,
            0.7,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO training_plans (
          id, user_id, weakness_cycle_id, theme, status,
          baseline_occurrences, current_occurrences, metadata,
          created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            plan_id,
            seed["user_id"],
            cycle_id,
            theme,
            1,
            0,
            0,
            json.dumps({}),
            now,
            now,
        ),
    )
    _seed_puzzles(conn, theme)

    return {"training_plan_id": plan_id, "user_id": seed["user_id"]}


def test_run_plan_generation_creates_assignments(db_conn):
    seeded = _seed_training_plan(db_conn)

    result = run_plan_generation(db_conn, seeded["training_plan_id"])

    assert result["assignments_created"] == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY

    count = db_conn.execute(
        "SELECT COUNT(*) FROM training_assignments WHERE training_plan_id = %s",
        (seeded["training_plan_id"],),
    ).fetchone()[0]
    assert count == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY

    plan = db_conn.execute(
        """
        SELECT starts_at, ends_at, baseline_occurrences, improvement_threshold, managed_threshold
        FROM training_plans
        WHERE id = %s
        """,
        (seeded["training_plan_id"],),
    ).fetchone()
    assert plan[0] is not None
    assert plan[1] is not None
    assert plan[2] == 4
    assert float(plan[3]) == 0.30
    assert float(plan[4]) == 0.75


def test_generate_training_plan_handler(db_conn):
    seeded = _seed_training_plan(db_conn)
    db_conn.commit()
    job = SystemJobRow(
        id=new_id(),
        user_id=seeded["user_id"],
        job_type=3,
        payload={"training_plan_id": seeded["training_plan_id"]},
    )

    result = generate_training_plan_handler(job)

    assert result["assignments_created"] == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY
    assert result["training_plan_id"] == seeded["training_plan_id"]


def test_run_plan_generation_is_idempotent_without_extension(db_conn):
    seeded = _seed_training_plan(db_conn)
    plan_id = seeded["training_plan_id"]

    first = run_plan_generation(db_conn, plan_id)
    second = run_plan_generation(db_conn, plan_id)

    assert first["assignments_created"] == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY
    assert second["assignments_created"] == 0

    count = db_conn.execute(
        "SELECT COUNT(*) FROM training_assignments WHERE training_plan_id = %s",
        (plan_id,),
    ).fetchone()[0]
    assert count == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY


def test_run_plan_generation_extension_appends_days(db_conn):
    seeded = _seed_training_plan(db_conn)
    plan_id = seeded["training_plan_id"]

    run_plan_generation(db_conn, plan_id)
    extension = run_plan_generation(db_conn, plan_id, extension=True)

    assert extension["assignments_created"] == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY

    count = db_conn.execute(
        "SELECT COUNT(*) FROM training_assignments WHERE training_plan_id = %s",
        (plan_id,),
    ).fetchone()[0]
    assert count == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY * 2

    day_indexes = db_conn.execute(
        """
        SELECT DISTINCT (metadata->>'day_index')::int
        FROM training_assignments
        WHERE training_plan_id = %s
        ORDER BY 1
        """,
        (plan_id,),
    ).fetchall()
    assert [row[0] for row in day_indexes] == list(range(PLAN_DURATION_DAYS * 2))


def test_generate_training_plan_handler_with_extension_payload(db_conn):
    seeded = _seed_training_plan(db_conn)
    db_conn.commit()
    plan_id = seeded["training_plan_id"]

    run_plan_generation(db_conn, plan_id)

    job = SystemJobRow(
        id=new_id(),
        user_id=seeded["user_id"],
        job_type=3,
        payload={"training_plan_id": plan_id, "extension": True},
    )

    result = generate_training_plan_handler(job)

    assert result["extension"] is True
    assert result["assignments_created"] == PLAN_DURATION_DAYS * ASSIGNMENTS_PER_DAY
