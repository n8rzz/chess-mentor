from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.weakness_package.aggregator import aggregate_by_theme, build_cycles, classify_artifacts
from worker.weakness_package.repository import WeaknessRepository

logger = logging.getLogger(__name__)


def run_classification(conn: psycopg.Connection, user_id: str) -> dict[str, Any]:
    repo = WeaknessRepository(conn)

    with conn.transaction():
        artifacts, games_analyzed = repo.load_window_artifacts(user_id)
        archived_cycle_numbers = repo.load_archived_cycle_numbers(user_id)
        repo.clear_rebuildable_cycles(user_id)

        classified = classify_artifacts(artifacts)
        aggregations = aggregate_by_theme(classified, games_analyzed=games_analyzed)
        cycles = build_cycles(
            aggregations,
            games_analyzed=games_analyzed,
            archived_cycle_numbers=archived_cycle_numbers,
        )

        cycle_ids: list[str] = []
        events_by_theme = {aggregation.theme: aggregation.events for aggregation in aggregations}

        for cycle in cycles:
            events = events_by_theme.get(cycle.theme, [])
            cycle_id = repo.insert_cycle_with_events(user_id, cycle, events)
            cycle_ids.append(cycle_id)

    summary = {
        "user_id": user_id,
        "games_analyzed": games_analyzed,
        "weakness_events_created": len(classified),
        "weakness_cycles_created": len(cycle_ids),
        "cycle_ids": cycle_ids,
    }
    logger.info("Weakness classification complete user_id=%s summary=%s", user_id, summary)
    return summary
