from __future__ import annotations

import chess

from worker.eval_package.constants import EVENT_TYPE, USER_COLOR
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.positions import MovePosition
from worker.eval_package.repository import AnalysisContext


def detect_king_safety(*, context: AnalysisContext, position: MovePosition) -> list[CandidateEventData]:
    if not position.parsed.played_by_user:
        return []

    board_after = chess.Board(position.fen_after)
    user_is_white = context.user_color == USER_COLOR["white"]
    king_square = board_after.king(chess.WHITE if user_is_white else chess.BLACK)
    if king_square is None:
        return []

    signals: list[str] = []
    if position.parsed.move_number <= 12 and not _has_castled(board_after, user_is_white):
        signals.append("delayed_castling")

    file_index = chess.square_file(king_square)
    rank_index = chess.square_rank(king_square)
    for file_delta in (-1, 0, 1):
        file_idx = file_index + file_delta
        if 0 <= file_idx <= 7:
            if not board_after.pieces(chess.PAWN, chess.WHITE if user_is_white else chess.BLACK) & chess.BB_FILES[file_idx]:
                signals.append("open_king_file")

    if rank_index in (0, 7) and signals:
        severity = 0.6
    elif signals:
        severity = 0.45
    else:
        return []

    return [
        CandidateEventData(
            event_type=EVENT_TYPE["king_safety"],
            severity=round(severity, 2),
            confidence=0.65,
            metadata={"signals": signals, "king_square": chess.square_name(king_square)},
        )
    ]


def _has_castled(board: chess.Board, user_is_white: bool) -> bool:
    color = chess.WHITE if user_is_white else chess.BLACK
    king_square = board.king(color)
    if king_square is None:
        return False
    file_index = chess.square_file(king_square)
    return file_index in (2, 6)
