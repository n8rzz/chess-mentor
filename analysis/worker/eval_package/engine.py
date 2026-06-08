from __future__ import annotations

import os
from dataclasses import dataclass

import chess
import chess.engine

from worker.eval_package.classifier import score_to_user_cp
from worker.eval_package.errors import EngineFailureError, EngineTimeoutError


@dataclass(frozen=True)
class EngineEvaluation:
    eval_before_cp: int
    eval_after_cp: int
    mate_before: int | None
    mate_after: int | None
    best_move_uci: str | None
    best_move_san: str | None
    principal_variation: str | None


class StockfishEvaluator:
    def __init__(self, *, stockfish_path: str, depth: int, user_is_white: bool) -> None:
        self._path = stockfish_path
        self._depth = depth
        self._user_is_white = user_is_white
        self._timeout = float(os.environ.get("ENGINE_TIMEOUT_SECONDS", "30"))
        self._engine: chess.engine.SimpleEngine | None = None

    def __enter__(self) -> StockfishEvaluator:
        try:
            self._engine = chess.engine.SimpleEngine.popen_uci(self._path)
            self._engine.configure({"Threads": 1, "Hash": 64})
        except Exception as exc:
            raise EngineFailureError(f"could not start Stockfish: {exc}") from exc
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self._engine is not None:
            self._engine.quit()
            self._engine = None

    @property
    def engine_version(self) -> str:
        if self._engine is None:
            return "unknown"
        return self._engine.id.get("name", "Stockfish")

    def evaluate_user_move(self, *, fen_before: str, fen_after: str, played_uci: str) -> EngineEvaluation:
        if self._engine is None:
            raise EngineFailureError("engine not started")

        board_before = chess.Board(fen_before)
        before = self._analyze(board_before)
        best_move = before["pv"][0] if before["pv"] else None
        best_move_uci = best_move.uci() if best_move else None
        best_move_san = board_before.san(best_move) if best_move else None
        pv_san = self._pv_to_san(board_before, before["pv"])

        board_after = chess.Board(fen_after)
        after = self._analyze(board_after)

        eval_before_cp = score_to_user_cp(
            cp=before["cp"],
            mate=before["mate"],
            user_is_white=self._user_is_white,
            white_to_move=board_before.turn == chess.WHITE,
        )
        eval_after_cp = score_to_user_cp(
            cp=after["cp"],
            mate=after["mate"],
            user_is_white=self._user_is_white,
            white_to_move=board_after.turn == chess.WHITE,
        )

        mate_before = self._user_mate_from_white(before["mate"], self._user_is_white)
        mate_after = self._user_mate_from_white(after["mate"], self._user_is_white)

        return EngineEvaluation(
            eval_before_cp=eval_before_cp,
            eval_after_cp=eval_after_cp,
            mate_before=mate_before,
            mate_after=mate_after,
            best_move_uci=best_move_uci,
            best_move_san=best_move_san,
            principal_variation=pv_san,
        )

    def _analyze(self, board: chess.Board) -> dict:
        assert self._engine is not None
        try:
            info = self._engine.analyse(
                board,
                chess.engine.Limit(depth=self._depth, time=self._timeout),
                info=chess.engine.INFO_ALL,
            )
        except chess.engine.EngineTerminatedError as exc:
            raise EngineFailureError(f"engine terminated: {exc}") from exc
        except TimeoutError as exc:
            raise EngineTimeoutError(f"engine timed out after {self._timeout}s") from exc
        except Exception as exc:
            raise EngineFailureError(f"engine analysis failed: {exc}") from exc

        score = info.get("score")
        if score is None:
            raise EngineFailureError("engine returned no score")

        white_score = score.white()
        cp = white_score.score(mate_score=10_000)
        mate = white_score.mate()

        pv = info.get("pv", [])
        return {"cp": cp, "mate": mate, "pv": pv}

    @staticmethod
    def _user_mate_from_white(mate: int | None, user_is_white: bool) -> int | None:
        if mate is None:
            return None
        return mate if user_is_white else -mate

    def _pv_to_san(self, board: chess.Board, pv: list[chess.Move]) -> str | None:
        if not pv:
            return None
        board_copy = board.copy()
        sans: list[str] = []
        for move in pv[:8]:
            try:
                sans.append(board_copy.san(move))
                board_copy.push(move)
            except ValueError:
                break
        return " ".join(sans) if sans else None
