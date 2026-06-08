from __future__ import annotations

import chess

from worker.eval_package.constants import EVENT_TYPE
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.positions import MovePosition


def detect_endgame_phase(*, position: MovePosition) -> list[CandidateEventData]:
    board_before = chess.Board(position.fen_before)
    board_after = chess.Board(position.fen_after)
    phase_before = _phase(board_before)
    phase_after = _phase(board_after)

    if phase_before == phase_after or phase_after != "endgame":
        return []

    return [
        CandidateEventData(
            event_type=EVENT_TYPE["endgame_phase"],
            severity=0.5,
            confidence=0.8,
            metadata={"phase_before": phase_before, "phase_after": phase_after},
        )
    ]


def _phase(board: chess.Board) -> str:
    queens = len(board.pieces(chess.QUEEN, chess.WHITE)) + len(board.pieces(chess.QUEEN, chess.BLACK))
    total_pieces = len(board.piece_map())
    if queens == 0 or total_pieces <= 10:
        return "endgame"
    if total_pieces <= 20:
        return "middlegame"
    return "opening"
