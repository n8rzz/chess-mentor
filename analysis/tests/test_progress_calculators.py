from decimal import Decimal

from worker.progress_package.calculators import (
    compute_plan_progress_percentage,
    compute_training_completion_percentage,
    compute_weakness_frequency,
)


def test_compute_plan_progress_percentage_reduces_occurrences():
    assert compute_plan_progress_percentage(10, 7) == 30.0


def test_compute_plan_progress_percentage_zero_baseline():
    assert compute_plan_progress_percentage(0, 5) == 0.0


def test_compute_plan_progress_percentage_never_negative():
    assert compute_plan_progress_percentage(5, 8) == 0.0


def test_compute_training_completion_percentage():
    assert compute_training_completion_percentage(3, 8) == 37.5


def test_compute_training_completion_percentage_zero_due():
    assert compute_training_completion_percentage(0, 0) is None


def test_compute_weakness_frequency_from_metadata():
    frequency = compute_weakness_frequency(2, 10, {"frequency": 0.4})
    assert frequency == 0.4


def test_compute_weakness_frequency_from_occurrences():
    frequency = compute_weakness_frequency(3, 10, {})
    assert frequency == 0.3
