from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import psycopg

from worker.import_package.constants import IMPORT_BATCH_STATUS, IMPORT_RECORD_STATUS, PROVIDER
from worker.import_package.ids import new_ulid


@dataclass(frozen=True)
class ImportContext:
    import_batch_id: str
    user_id: str
    provider_account_id: str
    provider: int
    provider_username: str
    access_token: str | None
    requested_since: datetime
    requested_until: datetime
    max_games: int
    time_controls: list[str]


class ImportRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def load_context(self, import_batch_id: str) -> ImportContext:
        row = self._conn.execute(
            """
            SELECT
              ib.id,
              ib.user_id,
              ib.provider_account_id,
              ib.provider,
              ib.requested_since,
              ib.requested_until,
              ib.max_games,
              ib.time_controls,
              pa.provider_username,
              pa.access_token
            FROM import_batches ib
            JOIN provider_accounts pa ON pa.id = ib.provider_account_id
            WHERE ib.id = %s
            """,
            (import_batch_id,),
        ).fetchone()

        if row is None:
            raise ValueError(f"import batch not found: {import_batch_id}")

        time_controls = row[7]
        if isinstance(time_controls, str):
            time_controls = json.loads(time_controls)

        return ImportContext(
            import_batch_id=row[0],
            user_id=row[1],
            provider_account_id=row[2],
            provider=row[3],
            provider_username=row[8],
            access_token=row[9],
            requested_since=row[4],
            requested_until=row[5],
            max_games=row[6],
            time_controls=list(time_controls),
        )

    def mark_batch_running(self, import_batch_id: str) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE import_batches
            SET status = %s, started_at = %s, updated_at = %s
            WHERE id = %s
            """,
            (IMPORT_BATCH_STATUS["running"], now, now, import_batch_id),
        )

    def mark_batch_finished(
        self,
        import_batch_id: str,
        *,
        status: str,
        games_found: int,
        games_imported: int,
        games_skipped: int,
        games_failed: int,
        error_message: str | None = None,
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE import_batches
            SET status = %s,
                finished_at = %s,
                updated_at = %s,
                games_found_count = %s,
                games_imported_count = %s,
                games_skipped_count = %s,
                games_failed_count = %s,
                error_message = %s
            WHERE id = %s
            """,
            (
                IMPORT_BATCH_STATUS[status],
                now,
                now,
                games_found,
                games_imported,
                games_skipped,
                games_failed,
                error_message,
                import_batch_id,
            ),
        )

    def touch_last_imported_at(self, provider_account_id: str) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            UPDATE provider_accounts
            SET last_imported_at = %s, updated_at = %s
            WHERE id = %s
            """,
            (now, now, provider_account_id),
        )

    def import_record_exists(self, provider: int, provider_game_id: str) -> bool:
        row = self._conn.execute(
            """
            SELECT 1 FROM import_records
            WHERE provider = %s AND provider_game_id = %s
            LIMIT 1
            """,
            (provider, provider_game_id),
        ).fetchone()
        return row is not None

    def game_exists(self, user_id: str, provider: int, provider_game_id: str) -> bool:
        row = self._conn.execute(
            """
            SELECT 1 FROM games
            WHERE user_id = %s AND provider = %s AND provider_game_id = %s
            LIMIT 1
            """,
            (user_id, provider, provider_game_id),
        ).fetchone()
        return row is not None

    def insert_import_record(
        self,
        *,
        import_batch_id: str,
        provider: int,
        provider_game_id: str,
        status: str,
        game_id: str | None = None,
        error_message: str | None = None,
    ) -> None:
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO import_records (
              id, import_batch_id, provider, provider_game_id, status,
              game_id, error_message, metadata, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
            """,
            (
                new_ulid(),
                import_batch_id,
                provider,
                provider_game_id,
                IMPORT_RECORD_STATUS[status],
                game_id,
                error_message,
                json.dumps({}),
                now,
                now,
            ),
        )

    def insert_game(
        self,
        *,
        context: ImportContext,
        attrs: dict[str, Any],
    ) -> str:
        game_id = new_ulid()
        now = _utcnow()
        self._conn.execute(
            """
            INSERT INTO games (
              id, user_id, provider_account_id, import_batch_id, provider,
              provider_game_id, pgn, played_at, user_color, result, time_control,
              time_class, opening_name, opening_eco, user_rating, opponent_rating,
              opponent_username, metadata, created_at, updated_at
            ) VALUES (
              %s, %s, %s, %s, %s,
              %s, %s, %s, %s, %s, %s,
              %s, %s, %s, %s, %s,
              %s, %s::jsonb, %s, %s
            )
            """,
            (
                game_id,
                context.user_id,
                context.provider_account_id,
                context.import_batch_id,
                attrs["provider"],
                attrs["provider_game_id"],
                attrs["pgn"],
                attrs["played_at"],
                attrs["user_color"],
                attrs["result"],
                attrs.get("time_control"),
                attrs["time_class"],
                attrs.get("opening_name"),
                attrs.get("opening_eco"),
                attrs.get("user_rating"),
                attrs.get("opponent_rating"),
                attrs.get("opponent_username"),
                json.dumps(attrs.get("metadata") or {}),
                now,
                now,
            ),
        )
        return game_id


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)
