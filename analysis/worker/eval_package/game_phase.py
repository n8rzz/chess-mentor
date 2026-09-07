"""Game-phase classification (opening / middlegame / endgame).

MVP rules (PHASE_CLASSIFIER_VERSION): material + move count, with monotonic
progression across a game. Keep integers aligned with Rails GamePhaseable.
"""

from __future__ import annotations

import chess

from worker.eval_package.positions import MovePosition

# Must match GamePhaseable::PHASES / weakness_package.constants.GAME_PHASE.
GAME_PHASE = {
    "opening": 0,
    "middlegame": 1,
    "endgame": 2,
}

PHASE_LABELS = {
    GAME_PHASE["opening"]: "opening",
    GAME_PHASE["middlegame"]: "middlegame",
    GAME_PHASE["endgame"]: "endgame",
}

# Keep aligned with Rails AnalysisVersions::PHASE_CLASSIFIER_VERSION.
PHASE_CLASSIFIER_VERSION = "1.0.0"

OPENING_MOVE_LIMIT = 15
ENDGAME_MAX_PIECES = 10
# Opening requires more pieces than this count (exclusive).
OPENING_MIN_PIECES = 20
# Material-only middlegame vs opening split for transition event labels.
MATERIAL_MIDDLEGAME_MAX_PIECES = 20


def is_endgame_board(board: chess.Board) -> bool:
    queens = len(board.pieces(chess.QUEEN, chess.WHITE)) + len(board.pieces(chess.QUEEN, chess.BLACK))
    total_pieces = len(board.piece_map())
    return queens == 0 or total_pieces <= ENDGAME_MAX_PIECES


def material_phase_label(board: chess.Board) -> str:
    """Material-only phase label used by the endgame transition detector."""
    if is_endgame_board(board):
        return "endgame"
    if len(board.piece_map()) <= MATERIAL_MIDDLEGAME_MAX_PIECES:
        return "middlegame"
    return "opening"


def classify_position_phase(
    fen: str,
    move_number: int,
    previous_phase: int | None = None,
) -> int:
    """Classify a single position; optionally clamp to never reverse phase."""
    raw = _raw_phase(fen, move_number)
    return _clamp_monotonic(raw, previous_phase)


def classify_game_phases(positions: list[MovePosition]) -> list[int]:
    """Classify every ply in order with monotonic progression."""
    phases: list[int] = []
    previous: int | None = None
    for position in positions:
        phase = classify_position_phase(
            position.fen_after,
            position.parsed.move_number,
            previous,
        )
        phases.append(phase)
        previous = phase
    return phases


def _raw_phase(fen: str, move_number: int) -> int:
    board = chess.Board(fen)
    total_pieces = len(board.piece_map())
    if is_endgame_board(board):
        return GAME_PHASE["endgame"]
    if move_number <= OPENING_MOVE_LIMIT and total_pieces > OPENING_MIN_PIECES:
        return GAME_PHASE["opening"]
    return GAME_PHASE["middlegame"]


def _clamp_monotonic(raw: int, previous: int | None) -> int:
    if previous is None:
        return raw
    # opening (0) < middlegame (1) < endgame (2)
    return max(previous, raw)
