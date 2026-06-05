from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import psycopg

logger = logging.getLogger(__name__)

# Must match Rails SystemJob enums (docs/planning/system-job-contract.md).
STATUS_PENDING = 0
STATUS_CLAIMED = 1
STATUS_PROCESSING = 2
STATUS_SUCCEEDED = 3
STATUS_FAILED = 4

JOB_TYPE_KEYS = {
    0: "import_games",
    1: "analyze_game",
    2: "classify_weaknesses",
    3: "generate_training_plan",
    4: "update_progress_snapshots",
}


@dataclass(frozen=True)
class SystemJobRow:
    id: str
    user_id: str
    job_type: int
    payload: dict[str, Any]

    @property
    def job_type_key(self) -> str:
        return JOB_TYPE_KEYS[self.job_type]


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def claim_next_job(conn: psycopg.Connection, worker_id: str) -> SystemJobRow | None:
    with conn.transaction():
        row = conn.execute(
            """
            SELECT id, user_id, job_type, payload
            FROM system_jobs
            WHERE status = %s
            ORDER BY created_at ASC
            LIMIT 1
            FOR UPDATE SKIP LOCKED
            """,
            (STATUS_PENDING,),
        ).fetchone()

        if row is None:
            return None

        job_id, user_id, job_type, payload = row
        now = _utcnow()

        conn.execute(
            """
            UPDATE system_jobs
            SET status = %s,
                claimed_by = %s,
                attempts_count = attempts_count + 1,
                started_at = %s,
                updated_at = %s
            WHERE id = %s
            """,
            (STATUS_CLAIMED, worker_id, now, now, job_id),
        )

        conn.execute(
            """
            UPDATE system_jobs
            SET status = %s, updated_at = %s
            WHERE id = %s
            """,
            (STATUS_PROCESSING, _utcnow(), job_id),
        )

        if isinstance(payload, dict):
            payload_dict = payload
        else:
            payload_dict = json.loads(payload) if payload else {}

        return SystemJobRow(
            id=job_id,
            user_id=user_id,
            job_type=job_type,
            payload=payload_dict,
        )


def mark_succeeded(
    conn: psycopg.Connection,
    job_id: str,
    result: dict[str, Any],
) -> None:
    now = _utcnow()
    conn.execute(
        """
        UPDATE system_jobs
        SET status = %s,
            result = %s::jsonb,
            finished_at = %s,
            updated_at = %s
        WHERE id = %s
        """,
        (STATUS_SUCCEEDED, json.dumps(result), now, now, job_id),
    )


def mark_failed(
    conn: psycopg.Connection,
    job_id: str,
    message: str,
    details: dict[str, Any] | None = None,
) -> None:
    now = _utcnow()
    conn.execute(
        """
        UPDATE system_jobs
        SET status = %s,
            error_message = %s,
            error_details = %s::jsonb,
            finished_at = %s,
            updated_at = %s
        WHERE id = %s
        """,
        (
            STATUS_FAILED,
            message,
            json.dumps(details or {}),
            now,
            now,
            job_id,
        ),
    )
