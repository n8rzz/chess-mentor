from __future__ import annotations

import chess

from worker.eval_package.constants import EVENT_TYPE, PIECE_VALUES
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.positions import MovePosition


def detect_material(*, position: MovePosition) -> list[CandidateEventData]:
    board_before = chess.Board(position.fen_before)
    board_after = chess.Board(position.fen_after)
    if not position.parsed.played_by_user:
        return []

    user_is_white = position.parsed.color == 0
    before = _user_material(board_before, user_is_white)
    after = _user_material(board_after, user_is_white)
    delta = after - before

    if delta >= 0:
        return []

    loss = -delta
    severity = min(1.0, loss / 9.0)
    confidence = 0.9 if loss >= 3 else 0.75
    return [
        CandidateEventData(
            event_type=EVENT_TYPE["material"],
            severity=round(severity, 2),
            confidence=round(confidence, 2),
            metadata={"material_delta": delta, "material_lost": loss},
        )
    ]


def _user_material(board: chess.Board, user_is_white: bool) -> int:
    total = 0
    for piece_type, value in PIECE_VALUES.items():
        piece = getattr(chess, piece_type.upper())
        if user_is_white:
            total += len(board.pieces(piece, chess.WHITE)) * value
            total -= len(board.pieces(piece, chess.BLACK)) * value
        else:
            total += len(board.pieces(piece, chess.BLACK)) * value
            total -= len(board.pieces(piece, chess.WHITE)) * value
    return total
