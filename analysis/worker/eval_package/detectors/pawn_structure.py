from __future__ import annotations

import chess

from worker.eval_package.constants import EVENT_TYPE, USER_COLOR
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.positions import MovePosition


def detect_pawn_structure(*, position: MovePosition) -> list[CandidateEventData]:
    if not position.parsed.played_by_user:
        return []

    board_before = chess.Board(position.fen_before)
    board_after = chess.Board(position.fen_after)
    user_is_white = position.parsed.color == 0
    color = chess.WHITE if user_is_white else chess.BLACK

    before_issues = _pawn_issues(board_before, color)
    after_issues = _pawn_issues(board_after, color)
    new_issues = sorted(set(after_issues) - set(before_issues))
    if not new_issues:
        return []

    return [
        CandidateEventData(
            event_type=EVENT_TYPE["pawn_structure"],
            severity=round(min(1.0, 0.35 + 0.15 * len(new_issues)), 2),
            confidence=0.7,
            metadata={"new_issues": new_issues},
        )
    ]


def _pawn_issues(board: chess.Board, color: chess.Color) -> list[str]:
    issues: list[str] = []
    pawns = board.pieces(chess.PAWN, color)
    pawn_squares = [sq for sq in chess.SQUARES if pawns & chess.BB_SQUARES[sq]]

    files_with_pawns: dict[int, list[int]] = {}
    for sq in pawn_squares:
        file_idx = chess.square_file(sq)
        files_with_pawns.setdefault(file_idx, []).append(sq)

    for file_idx, squares in files_with_pawns.items():
        if len(squares) > 1:
            issues.append(f"doubled_pawn_file_{file_idx}")

    for sq in pawn_squares:
        file_idx = chess.square_file(sq)
        rank_idx = chess.square_rank(sq)
        adjacent_files = [f for f in (file_idx - 1, file_idx + 1) if 0 <= f <= 7]
        has_adjacent_pawn = any(
            board.piece_at(chess.square(f, r)) and board.piece_at(chess.square(f, r)).piece_type == chess.PAWN
            and board.piece_at(chess.square(f, r)).color == color
            for f in adjacent_files
            for r in range(8)
        )
        if not has_adjacent_pawn:
            issues.append(f"isolated_pawn_{chess.square_name(sq)}")

        if not _is_passed(board, sq, color):
            continue
        if rank_idx >= (5 if color == chess.WHITE else 2):
            issues.append(f"passed_pawn_{chess.square_name(sq)}")

    return issues


def _is_passed(board: chess.Board, square: int, color: chess.Color) -> bool:
    file_idx = chess.square_file(square)
    rank_idx = chess.square_rank(square)
    opponent = not color
    for f in range(max(0, file_idx - 1), min(7, file_idx + 1) + 1):
        for r in range(rank_idx + 1, 8) if color == chess.WHITE else range(rank_idx - 1, -1, -1):
            piece = board.piece_at(chess.square(f, r))
            if piece and piece.piece_type == chess.PAWN and piece.color == opponent:
                return False
    return True
