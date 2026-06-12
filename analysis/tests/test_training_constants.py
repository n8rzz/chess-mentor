from worker.training_package.constants import IMPROVING_THRESHOLD, MANAGED_THRESHOLD
from worker.weakness_package.constants import IMPROVING_THRESHOLD as WEAKNESS_IMPROVING
from worker.weakness_package.constants import MANAGED_THRESHOLD as WEAKNESS_MANAGED


def test_training_thresholds_match_weakness_classifier():
    assert IMPROVING_THRESHOLD == WEAKNESS_IMPROVING
    assert MANAGED_THRESHOLD == WEAKNESS_MANAGED
