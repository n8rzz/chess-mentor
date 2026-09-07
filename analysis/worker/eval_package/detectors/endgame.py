from __future__ import annotations

import chess

from worker.eval_package.constants import EVENT_TYPE
from worker.eval_package.detectors.types import AnalysisEventData
from worker.eval_package.game_phase import material_phase_label
from worker.eval_package.positions import MovePosition


def detect_endgame_phase(*, position: MovePosition) -> list[AnalysisEventData]:
    board_before = chess.Board(position.fen_before)
    board_after = chess.Board(position.fen_after)
    phase_before = material_phase_label(board_before)
    phase_after = material_phase_label(board_after)

    if phase_before == phase_after or phase_after != "endgame":
        return []

    return [
        AnalysisEventData(
            event_type=EVENT_TYPE["endgame_phase"],
            severity=0.5,
            confidence=0.8,
            metadata={"phase_before": phase_before, "phase_after": phase_after},
        )
    ]
