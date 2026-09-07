from datetime import datetime, timedelta, timezone

from worker.jobs import STATUS_PENDING, STATUS_PROCESSING, heartbeat_job
from db_helpers import new_id, seed_import_batch


def _insert_processing_job(conn, *, user_id: str, updated_at: datetime) -> str:
    job_id = new_id()
    now = datetime.now(timezone.utc)
    conn.execute(
        """
        INSERT INTO system_jobs (
          id, user_id, job_type, status, payload, attempts_count,
          claimed_by, started_at, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s, %s, %s, %s)
        """,
        (
            job_id,
            user_id,
            1,
            STATUS_PROCESSING,
            "{}",
            1,
            "worker-test",
            updated_at,
            now,
            updated_at,
        ),
    )
    return job_id


def test_heartbeat_job_bumps_updated_at_for_processing_jobs(db_conn):
    seed = seed_import_batch(db_conn)
    stale = datetime.now(timezone.utc) - timedelta(hours=1)
    job_id = _insert_processing_job(db_conn, user_id=seed["user_id"], updated_at=stale)

    assert heartbeat_job(db_conn, job_id) is True

    row = db_conn.execute(
        "SELECT updated_at, status FROM system_jobs WHERE id = %s",
        (job_id,),
    ).fetchone()
    assert row[1] == STATUS_PROCESSING
    updated_at = row[0]
    if updated_at.tzinfo is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    assert updated_at > stale


def test_heartbeat_job_skips_terminal_jobs(db_conn):
    seed = seed_import_batch(db_conn)
    job_id = new_id()
    now = datetime.now(timezone.utc)
    db_conn.execute(
        """
        INSERT INTO system_jobs (
          id, user_id, job_type, status, payload, attempts_count,
          created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s, %s)
        """,
        (job_id, seed["user_id"], 1, STATUS_PENDING, "{}", 0, now, now),
    )

    assert heartbeat_job(db_conn, job_id) is False
