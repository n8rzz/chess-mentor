from datetime import datetime, timedelta, timezone

from worker.weakness_package.aggregator import (
    aggregate_by_theme,
    build_cycles,
    classify_artifacts,
    compute_cycle_severity,
    dedupe_by_game_and_theme,
)
from worker.weakness_package.constants import CYCLE_STATUS, WEAKNESS_THEME
from worker.weakness_package.types import ClassifiedWeakness, MoveArtifact, ThemeAggregation


def _classified(
    *,
    theme: int,
    game_id: str,
    move_id: str,
    played_at: datetime,
    severity: float = 0.7,
) -> ClassifiedWeakness:
    return ClassifiedWeakness(
        user_id="user-1",
        game_id=game_id,
        move_id=move_id,
        primary_theme=theme,
        secondary_theme=None,
        severity=severity,
        phase=1,
        occurred_under_time_pressure=False,
        explanation_key="test.v1",
        metadata={},
        played_at=played_at,
    )


def test_aggregate_by_theme_groups_events():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
        _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g2", move_id="m2", played_at=now),
        _classified(theme=WEAKNESS_THEME["hanging_pieces"], game_id="g1", move_id="m3", played_at=now),
    ]
    aggregations = aggregate_by_theme(events, games_analyzed=3)
    by_theme = {item.theme: item for item in aggregations}
    assert by_theme[WEAKNESS_THEME["missed_tactics"]].occurrences == 2
    assert by_theme[WEAKNESS_THEME["hanging_pieces"]].occurrences == 1


def test_build_cycles_promotes_active_when_recurring():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
        _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g2", move_id="m2", played_at=now - timedelta(days=1)),
        _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g3", move_id="m3", played_at=now - timedelta(days=2)),
    ]
    aggregations = aggregate_by_theme(events, games_analyzed=5)
    cycles = build_cycles(aggregations, games_analyzed=5, archived_cycle_numbers={})
    assert len(cycles) == 1
    assert cycles[0].status == CYCLE_STATUS["active"]
    assert cycles[0].current_occurrences == 3


def test_build_cycles_stays_detected_below_threshold():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
    ]
    aggregations = aggregate_by_theme(events, games_analyzed=5)
    cycles = build_cycles(aggregations, games_analyzed=5, archived_cycle_numbers={})
    assert cycles[0].status == CYCLE_STATUS["detected"]


def test_compute_cycle_severity_is_bounded():
    now = datetime.now(timezone.utc)
    aggregation = ThemeAggregation(
        theme=WEAKNESS_THEME["missed_tactics"],
        events=[
            _classified(theme=WEAKNESS_THEME["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
        ],
    )
    severity = compute_cycle_severity(aggregation, games_analyzed=5, reference_time=now)
    assert 0.0 <= severity <= 1.0


def test_classify_artifacts_returns_empty_for_no_signals():
    assert classify_artifacts([]) == []


def test_dedupe_by_game_and_theme_keeps_highest_severity_per_game():
    now = datetime.now(timezone.utc)
    theme = WEAKNESS_THEME["opening_development"]
    events = [
        _classified(theme=theme, game_id="g1", move_id="m1", played_at=now, severity=0.4),
        _classified(theme=theme, game_id="g1", move_id="m2", played_at=now, severity=0.8),
        _classified(theme=theme, game_id="g2", move_id="m3", played_at=now, severity=0.6),
    ]

    deduped = dedupe_by_game_and_theme(events)

    assert len(deduped) == 2
    by_game = {event.game_id: event for event in deduped}
    assert by_game["g1"].severity == 0.8
    assert by_game["g1"].move_id == "m2"


def test_build_cycles_frequency_is_capped_by_games_analyzed():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=WEAKNESS_THEME["king_safety"], game_id=f"g{i}", move_id=f"m{i}", played_at=now)
        for i in range(5)
    ]
    aggregations = aggregate_by_theme(events, games_analyzed=12)
    cycles = build_cycles(aggregations, games_analyzed=12, archived_cycle_numbers={})

    assert cycles[0].frequency == round(5 / 12, 4)
    assert cycles[0].current_occurrences == 5
