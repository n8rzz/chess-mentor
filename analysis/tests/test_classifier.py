from worker.eval_package.classifier import (
    centipawn_loss,
    classify_move,
    evaluation_metadata,
    score_to_user_cp,
)
from worker.eval_package.constants import CLASSIFICATION, TIME_CLASS


def test_centipawn_loss_is_non_negative():
    assert centipawn_loss(120, 40) == 80
    assert centipawn_loss(40, 120) == 0


def test_classify_move_thresholds():
    assert classify_move(10) == CLASSIFICATION["good"]
    assert classify_move(75) == CLASSIFICATION["inaccuracy"]
    assert classify_move(150) == CLASSIFICATION["mistake"]
    assert classify_move(400) == CLASSIFICATION["blunder"]


def test_score_to_user_cp_flips_for_black():
    assert score_to_user_cp(cp=50, mate=None, user_is_white=False, white_to_move=True) == -50


def test_evaluation_metadata_includes_time_weight():
    metadata = evaluation_metadata(time_class=TIME_CLASS["blitz"], cpl=80)
    assert metadata["time_control_weight"] == 0.75
    assert metadata["weighted_centipawn_loss"] == 60.0
