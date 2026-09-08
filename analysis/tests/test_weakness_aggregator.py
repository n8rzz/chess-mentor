from datetime import datetime, timedelta, timezone

from worker.weakness_package.aggregator import (
    aggregate_by_pattern,
    build_cycles,
    classify_artifacts,
    compute_cycle_severity,
    dedupe_by_game_and_theme,
)
from worker.weakness_package.constants import CYCLE_STATUS, PATTERN
from worker.weakness_package.types import ClassifiedPattern, MoveArtifact, PatternAggregation


def _classified(
    *,
    theme: int,
    game_id: str,
    move_id: str,
    played_at: datetime,
    severity: float = 0.7,
    confidence: float = 0.85,
) -> ClassifiedPattern:
    return ClassifiedPattern(
        user_id="user-1",
        game_id=game_id,
        move_id=move_id,
        primary_pattern=theme,
        secondary_pattern=None,
        severity=severity,
        confidence=confidence,
        phase=1,
        occurred_under_time_pressure=False,
        explanation_key="test.v1",
        metadata={},
        played_at=played_at,
    )


def test_aggregate_by_pattern_groups_events():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=PATTERN["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
        _classified(theme=PATTERN["missed_tactics"], game_id="g2", move_id="m2", played_at=now),
        _classified(theme=PATTERN["hanging_pieces"], game_id="g1", move_id="m3", played_at=now),
    ]
    aggregations = aggregate_by_pattern(events, games_analyzed=3)
    by_pattern = {item.pattern: item for item in aggregations}
    assert by_pattern[PATTERN["missed_tactics"]].occurrences == 2
    assert by_pattern[PATTERN["hanging_pieces"]].occurrences == 1


def test_build_cycles_promotes_active_when_recurring():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=PATTERN["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
        _classified(theme=PATTERN["missed_tactics"], game_id="g2", move_id="m2", played_at=now - timedelta(days=1)),
        _classified(theme=PATTERN["missed_tactics"], game_id="g3", move_id="m3", played_at=now - timedelta(days=2)),
    ]
    aggregations = aggregate_by_pattern(events, games_analyzed=5)
    cycles = build_cycles(aggregations, games_analyzed=5, archived_cycle_numbers={})
    assert len(cycles) == 1
    assert cycles[0].status == CYCLE_STATUS["active"]
    assert cycles[0].current_occurrences == 3


def test_build_cycles_stays_detected_below_threshold():
    now = datetime.now(timezone.utc)
    events = [
        _classified(theme=PATTERN["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
    ]
    aggregations = aggregate_by_pattern(events, games_analyzed=5)
    cycles = build_cycles(aggregations, games_analyzed=5, archived_cycle_numbers={})
    assert cycles[0].status == CYCLE_STATUS["detected"]


def test_compute_cycle_severity_is_bounded():
    now = datetime.now(timezone.utc)
    aggregation = PatternAggregation(
        pattern=PATTERN["missed_tactics"],
        events=[
            _classified(theme=PATTERN["missed_tactics"], game_id="g1", move_id="m1", played_at=now),
        ],
    )
    severity = compute_cycle_severity(aggregation, games_analyzed=5, reference_time=now)
    assert 0.0 <= severity <= 1.0


def test_classify_artifacts_returns_empty_for_no_signals():
    assert classify_artifacts([]) == []


def test_dedupe_by_game_and_theme_keeps_highest_severity_per_game():
    now = datetime.now(timezone.utc)
    theme = PATTERN["opening_development"]
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
        _classified(theme=PATTERN["king_safety"], game_id=f"g{i}", move_id=f"m{i}", played_at=now)
        for i in range(5)
    ]
    aggregations = aggregate_by_pattern(events, games_analyzed=12)
    cycles = build_cycles(aggregations, games_analyzed=12, archived_cycle_numbers={})

    assert cycles[0].frequency == round(5 / 12, 4)
    assert cycles[0].current_occurrences == 5


def test_dedupe_keeps_multiple_themes_on_same_move():
    now = datetime.now(timezone.utc)
    events = [
        _classified(
            theme=PATTERN["hanging_pieces"],
            game_id="g1",
            move_id="m1",
            played_at=now,
            severity=0.7,
        ),
        _classified(
            theme=PATTERN["moving_too_quickly"],
            game_id="g1",
            move_id="m1",
            played_at=now,
            severity=0.65,
        ),
        _classified(
            theme=PATTERN["hanging_pieces"],
            game_id="g1",
            move_id="m2",
            played_at=now,
            severity=0.9,
        ),
    ]

    deduped = dedupe_by_game_and_theme(events)

    assert len(deduped) == 2
    by_theme = {event.primary_pattern: event for event in deduped}
    assert by_theme[PATTERN["hanging_pieces"]].move_id == "m2"
    assert by_theme[PATTERN["hanging_pieces"]].severity == 0.9
    assert by_theme[PATTERN["moving_too_quickly"]].move_id == "m1"


def test_classify_artifacts_drops_low_confidence(monkeypatch):
    now = datetime.now(timezone.utc)
    artifact = MoveArtifact(
        move_id="move-1",
        game_id="game-1",
        user_id="user-1",
        move_number=20,
        san="Qh5",
        played_at=now,
        time_class=1,
        ply=39,
        phase=1,
    )

    def fake_classify(_artifact):
        return [
            _classified(
                theme=PATTERN["hanging_pieces"],
                game_id="game-1",
                move_id="move-1",
                played_at=now,
                confidence=0.5,
            )
        ]

    monkeypatch.setattr(
        "worker.weakness_package.aggregator.classify_move",
        fake_classify,
    )
    monkeypatch.setattr(
        "worker.weakness_package.aggregator.classify_lost_winning_positions",
        lambda _artifacts: [],
    )
    monkeypatch.setattr(
        "worker.weakness_package.aggregator._standalone_time_pressure_qualifies",
        lambda *_args, **_kwargs: False,
    )

    assert classify_artifacts([artifact]) == []
