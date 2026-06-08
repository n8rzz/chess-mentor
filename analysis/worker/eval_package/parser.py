from __future__ import annotations

import io
import re
from dataclasses import dataclass

import chess
import chess.pgn

from worker.eval_package.constants import MOVE_COLOR, USER_COLOR
from worker.eval_package.errors import InvalidPgnError

_CLOCK_RE = re.compile(r"\[%clk\s+([^\]]+)\]")


@dataclass(frozen=True)
class ParsedMove:
    ply: int
    move_number: int
    color: int
    san: str
    uci: str
    played_by_user: bool
    clock_before: int | None
    clock_after: int | None


def parse_pgn(pgn_text: str, *, user_color: int) -> list[ParsedMove]:
    try:
        game = chess.pgn.read_game(io.StringIO(pgn_text))
    except Exception as exc:
        raise InvalidPgnError(f"could not read PGN: {exc}") from exc

    if game is None:
        raise InvalidPgnError("empty or missing game in PGN")

    user_is_white = user_color == USER_COLOR["white"]
    moves: list[ParsedMove] = []
    node = game

    while node.variations:
        node = node.variation(0)
        move = node.move
        if move is None:
            raise InvalidPgnError("incomplete game: null move in mainline")

        parent = node.parent
        if parent is None:
            raise InvalidPgnError("incomplete game: missing parent node")

        board = parent.board()
        ply = board.fullmove_number * 2 - 1 if board.turn == chess.WHITE else board.fullmove_number * 2
        color = MOVE_COLOR["white"] if board.turn == chess.WHITE else MOVE_COLOR["black"]
        move_number = board.fullmove_number
        played_by_user = (board.turn == chess.WHITE) == user_is_white

        clock_after = _parse_clock_comment(node.comment)
        clock_before = _parse_clock_comment(parent.comment) if parent.comment else None

        try:
            san = board.san(move)
        except ValueError as exc:
            raise InvalidPgnError(f"illegal move {move.uci()} at ply {ply}: {exc}") from exc

        moves.append(
            ParsedMove(
                ply=ply,
                move_number=move_number,
                color=color,
                san=san,
                uci=move.uci(),
                played_by_user=played_by_user,
                clock_before=clock_before,
                clock_after=clock_after,
            )
        )

    if not moves:
        raise InvalidPgnError("game has no moves")

    return moves


def _parse_clock_comment(comment: str) -> int | None:
    if not comment:
        return None
    match = _CLOCK_RE.search(comment)
    if match is None:
        return None
    return _clock_text_to_seconds(match.group(1).strip())


def _clock_text_to_seconds(text: str) -> int | None:
    parts = text.split(":")
    try:
        if len(parts) == 3:
            hours, minutes, seconds = (int(float(p)) for p in parts)
            return hours * 3600 + minutes * 60 + seconds
        if len(parts) == 2:
            minutes, seconds = (int(float(p)) for p in parts)
            return minutes * 60 + seconds
        if len(parts) == 1:
            return int(float(parts[0]))
    except ValueError:
        return None
    return None
