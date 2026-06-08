from __future__ import annotations

import chess

from worker.eval_package.constants import CPL_THRESHOLDS, EVENT_TYPE
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.engine import EngineEvaluation
from worker.eval_package.positions import MovePosition


def detect_tactical(
    *,
    position: MovePosition,
    evaluation: EngineEvaluation,
    cpl: int,
) -> list[CandidateEventData]:
    if not position.parsed.played_by_user:
        return []

    if cpl < CPL_THRESHOLDS["inaccuracy"]:
        return []

    board_before = chess.Board(position.fen_before)
    played = chess.Move.from_uci(position.parsed.uci)
    best = chess.Move.from_uci(evaluation.best_move_uci) if evaluation.best_move_uci else None

    missed_tactic = False
    if best is not None:
        best_capture_or_check = board_before.is_capture(best) or _gives_check(board_before, best)
        played_capture_or_check = board_before.is_capture(played) or _gives_check(board_before, played)
        missed_tactic = best_capture_or_check and not played_capture_or_check and best != played

    if not missed_tactic and not (board_before.is_capture(played) and cpl >= CPL_THRESHOLDS["mistake"]):
        return []

    severity = min(1.0, cpl / 500.0)
    return [
        CandidateEventData(
            event_type=EVENT_TYPE["tactical"],
            severity=round(max(severity, 0.4), 2),
            confidence=0.8,
            metadata={
                "centipawn_loss": cpl,
                "missed_tactic": missed_tactic,
                "best_move_uci": evaluation.best_move_uci,
            },
        )
    ]


def _gives_check(board: chess.Board, move: chess.Move) -> bool:
    board_copy = board.copy()
    board_copy.push(move)
    return board_copy.is_check()
