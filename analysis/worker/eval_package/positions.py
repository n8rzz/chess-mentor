from __future__ import annotations

import io
from dataclasses import dataclass

import chess
import chess.pgn

from worker.eval_package.errors import InvalidPgnError, PositionReconstructionError
from worker.eval_package.parser import ParsedMove, parse_pgn


@dataclass(frozen=True)
class MovePosition:
    parsed: ParsedMove
    fen_before: str
    fen_after: str


def generate_positions(pgn_text: str, *, user_color: int) -> list[MovePosition]:
    parsed_moves = parse_pgn(pgn_text, user_color=user_color)

    try:
        game = chess.pgn.read_game(io.StringIO(pgn_text))
    except Exception as exc:
        raise InvalidPgnError(f"could not read PGN: {exc}") from exc

    if game is None:
        raise InvalidPgnError("empty or missing game in PGN")

    node = game
    positions: list[MovePosition] = []

    for parsed in parsed_moves:
        node = node.variation(0)
        move = node.move
        if move is None:
            raise PositionReconstructionError("null move while replaying mainline")

        parent = node.parent
        if parent is None:
            raise PositionReconstructionError("missing parent while replaying mainline")

        fen_before = parent.board().fen()
        fen_after = node.board().fen()

        positions.append(
            MovePosition(
                parsed=parsed,
                fen_before=fen_before,
                fen_after=fen_after,
            )
        )

    if len(positions) != len(parsed_moves):
        raise PositionReconstructionError("move count mismatch during replay")

    return positions
