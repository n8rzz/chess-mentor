from __future__ import annotations

import chess

from worker.eval_package.constants import CPL_THRESHOLDS, EVENT_TYPE
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.engine import EngineEvaluation
from worker.eval_package.positions import MovePosition


def detect_threat(
    *,
    position: MovePosition,
    evaluation: EngineEvaluation,
    cpl: int,
) -> list[CandidateEventData]:
    if not position.parsed.played_by_user:
        return []

    board_before = chess.Board(position.fen_before)
    hanging_before = _hanging_pieces(board_before, board_before.turn)
    if not hanging_before:
        return []

    if cpl < CPL_THRESHOLDS["inaccuracy"]:
        return []

    return [
        CandidateEventData(
            event_type=EVENT_TYPE["threat"],
            severity=round(min(1.0, cpl / 400.0), 2),
            confidence=0.7,
            metadata={
                "ignored_hanging_pieces": hanging_before,
                "centipawn_loss": cpl,
            },
        )
    ]


def _hanging_pieces(board: chess.Board, color: chess.Color) -> list[str]:
    hanging: list[str] = []
    for square in chess.SQUARES:
        piece = board.piece_at(square)
        if piece is None or piece.color != color:
            continue
        if board.is_attacked_by(not color, square) and not board.is_attacked_by(color, square):
            hanging.append(chess.square_name(square))
    return hanging
