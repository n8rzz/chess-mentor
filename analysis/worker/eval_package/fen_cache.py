from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

import psycopg

from worker.eval_package.logging_utils import log_cache
from worker.import_package.ids import new_ulid


def normalize_position_key(fen: str) -> str:
    """Normalize FEN to the first four fields (board, side, castling, ep)."""
    parts = fen.strip().split()
    if len(parts) < 4:
        raise ValueError(f"invalid FEN for cache key: {fen!r}")
    return " ".join(parts[:4])


class EnginePositionCache:
    """Cross-game cache of Stockfish position analysis keyed by FEN + settings."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn
        self.hits = 0
        self.misses = 0

    def get(
        self,
        *,
        fen: str,
        engine_name: str,
        engine_version: str,
        depth: int,
        multipv: int,
        analysis_version: str,
    ) -> dict[str, Any] | None:
        position_key = normalize_position_key(fen)
        row = self._conn.execute(
            """
            SELECT result
            FROM engine_position_evals
            WHERE position_key = %s
              AND engine_name = %s
              AND engine_version = %s
              AND depth = %s
              AND multipv = %s
              AND analysis_version = %s
            LIMIT 1
            """,
            (position_key, engine_name, engine_version, depth, multipv, analysis_version),
        ).fetchone()

        if row is None:
            self.misses += 1
            log_cache(
                "miss",
                position_key=position_key,
                depth=depth,
                multipv=multipv,
                analysis_version=analysis_version,
            )
            return None

        self.hits += 1
        result = row[0]
        if isinstance(result, str):
            result = json.loads(result)
        log_cache(
            "hit",
            position_key=position_key,
            depth=depth,
            multipv=multipv,
            analysis_version=analysis_version,
        )
        return dict(result or {})

    def put(
        self,
        *,
        fen: str,
        engine_name: str,
        engine_version: str,
        depth: int,
        multipv: int,
        analysis_version: str,
        result: dict[str, Any],
    ) -> None:
        position_key = normalize_position_key(fen)
        now = datetime.now(timezone.utc)
        self._conn.execute(
            """
            INSERT INTO engine_position_evals (
              id, position_key, engine_name, engine_version, depth, multipv,
              analysis_version, result, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
            ON CONFLICT (position_key, engine_name, engine_version, depth, multipv, analysis_version)
            DO UPDATE SET result = EXCLUDED.result, updated_at = EXCLUDED.updated_at
            """,
            (
                new_ulid(),
                position_key,
                engine_name,
                engine_version,
                depth,
                multipv,
                analysis_version,
                json.dumps(result),
                now,
                now,
            ),
        )
        log_cache(
            "write",
            position_key=position_key,
            depth=depth,
            multipv=multipv,
            analysis_version=analysis_version,
        )
