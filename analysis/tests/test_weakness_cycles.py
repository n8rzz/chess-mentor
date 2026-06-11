from worker.weakness_package.constants import CYCLE_STATUS
from worker.weakness_package.cycles import resolve_status, transition_status_for_improvement


def test_resolve_status_active_when_threshold_met():
    status = resolve_status(
        occurrences=3,
        games_with_occurrences=2,
        baseline_occurrences=3,
        current_occurrences=3,
    )
    assert status == CYCLE_STATUS["active"]


def test_resolve_status_detected_when_below_threshold():
    status = resolve_status(
        occurrences=2,
        games_with_occurrences=1,
        baseline_occurrences=2,
        current_occurrences=2,
    )
    assert status == CYCLE_STATUS["detected"]


def test_transition_status_improving_at_thirty_percent_reduction():
    status = transition_status_for_improvement(
        CYCLE_STATUS["active"],
        baseline_occurrences=10,
        current_occurrences=6,
    )
    assert status == CYCLE_STATUS["improving"]


def test_transition_status_managed_at_seventy_five_percent_reduction():
    status = transition_status_for_improvement(
        CYCLE_STATUS["active"],
        baseline_occurrences=10,
        current_occurrences=2,
    )
    assert status == CYCLE_STATUS["managed"]
