from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.import_package.constants import PROVIDER
from worker.import_package.lichess_client import (
    LichessApiError,
    LichessAuthError,
    LichessClient,
    normalize_lichess_game,
)
from worker.import_package.repository import ImportRepository

logger = logging.getLogger(__name__)


def run_import(conn: psycopg.Connection, import_batch_id: str) -> dict[str, Any]:
    repo = ImportRepository(conn)
    context = repo.load_context(import_batch_id)

    if context.provider != PROVIDER["lichess"]:
        repo.mark_batch_finished(
            import_batch_id,
            status="failed",
            games_found=0,
            games_imported=0,
            games_skipped=0,
            games_failed=0,
            error_message="Only Lichess imports are supported",
        )
        raise ValueError("unsupported provider")

    repo.mark_batch_running(import_batch_id)

    try:
        summary = _import_lichess(conn, repo, context)
    except LichessAuthError as exc:
        repo.mark_batch_finished(
            import_batch_id,
            status="failed",
            games_found=0,
            games_imported=0,
            games_skipped=0,
            games_failed=0,
            error_message=str(exc),
        )
        raise
    except LichessApiError as exc:
        repo.mark_batch_finished(
            import_batch_id,
            status="failed",
            games_found=0,
            games_imported=0,
            games_skipped=0,
            games_failed=0,
            error_message=str(exc),
        )
        raise

    repo.touch_last_imported_at(context.provider_account_id)
    return summary


def _import_lichess(
    conn: psycopg.Connection,
    repo: ImportRepository,
    context,
) -> dict[str, Any]:
    if not context.access_token:
        repo.mark_batch_finished(
            context.import_batch_id,
            status="failed",
            games_found=0,
            games_imported=0,
            games_skipped=0,
            games_failed=0,
            error_message="Missing Lichess access token",
        )
        raise LichessAuthError("Missing Lichess access token")

    client = LichessClient(context.access_token)
    since_ms = int(context.requested_since.timestamp() * 1000)
    until_ms = int(context.requested_until.timestamp() * 1000)

    games = client.fetch_games(
        context.provider_username,
        since_ms=since_ms,
        until_ms=until_ms,
        max_games=context.max_games,
        perf_types=context.time_controls,
    )

    games_found = len(games)
    games_imported = 0
    games_skipped = 0
    games_failed = 0

    for lichess_game in games:
        provider_game_id = lichess_game.raw.get("id", "unknown")

        try:
            if repo.import_record_exists(context.provider, provider_game_id) or repo.game_exists(
                context.user_id, context.provider, provider_game_id
            ):
                games_skipped += 1
                continue

            attrs = normalize_lichess_game(lichess_game, account_username=context.provider_username)

            with conn.transaction():
                game_id = repo.insert_game(context=context, attrs=attrs)
                repo.insert_import_record(
                    import_batch_id=context.import_batch_id,
                    provider=context.provider,
                    provider_game_id=provider_game_id,
                    status="imported",
                    game_id=game_id,
                )
            games_imported += 1
        except Exception as exc:
            logger.exception("Failed to import game %s", provider_game_id)
            games_failed += 1
            try:
                with conn.transaction():
                    repo.insert_import_record(
                        import_batch_id=context.import_batch_id,
                        provider=context.provider,
                        provider_game_id=provider_game_id,
                        status="failed",
                        error_message=str(exc),
                    )
            except Exception:
                logger.exception("Could not record failed import for %s", provider_game_id)

    status = _terminal_status(games_imported, games_failed, games_found)
    repo.mark_batch_finished(
        context.import_batch_id,
        status=status,
        games_found=games_found,
        games_imported=games_imported,
        games_skipped=games_skipped,
        games_failed=games_failed,
    )

    return {
        "import_batch_id": context.import_batch_id,
        "status": status,
        "games_found": games_found,
        "games_imported": games_imported,
        "games_skipped": games_skipped,
        "games_failed": games_failed,
    }


def _terminal_status(imported: int, failed: int, found: int) -> str:
    if imported == 0 and failed > 0:
        return "failed"
    if failed > 0 or (imported > 0 and imported < found):
        return "partially_succeeded"
    if imported > 0:
        return "succeeded"
    if found == 0:
        return "succeeded"
    return "succeeded"
