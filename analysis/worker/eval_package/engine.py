from __future__ import annotations

import os
from dataclasses import asdict, dataclass
from typing import Any

import chess
import chess.engine

from worker.eval_package.classifier import score_to_user_cp
from worker.eval_package.errors import EngineFailureError, EngineTimeoutError
from worker.eval_package.fen_cache import EnginePositionCache
from worker.eval_package.logging_utils import log_verbose


@dataclass(frozen=True)
class CandidateLine:
    rank: int
    move_uci: str | None
    move_san: str | None
    eval_cp: int
    mate: int | None
    pv_san: str | None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class EngineEvaluation:
    eval_before_cp: int
    eval_after_cp: int
    mate_before: int | None
    mate_after: int | None
    best_move_uci: str | None
    best_move_san: str | None
    principal_variation: str | None
    candidates: tuple[CandidateLine, ...] = ()
    depth: int | None = None
    multipv: int | None = None
    played_is_best: bool | None = None
    cache_hit_before: bool = False
    cache_hit_after: bool = False


class StockfishEvaluator:
    def __init__(
        self,
        *,
        stockfish_path: str,
        user_is_white: bool,
        engine_name: str,
        engine_version: str,
        analysis_version: str,
        cache: EnginePositionCache | None = None,
    ) -> None:
        self._path = stockfish_path
        self._user_is_white = user_is_white
        self._engine_name = engine_name
        self._engine_version = engine_version
        self._analysis_version = analysis_version
        self._cache = cache
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
    def engine_version_observed(self) -> str:
        if self._engine is None:
            return "unknown"
        return self._engine.id.get("name", "Stockfish")

    def evaluate_user_move(
        self,
        *,
        fen_before: str,
        fen_after: str,
        played_uci: str,
        depth: int,
        multipv: int,
    ) -> EngineEvaluation:
        before_lines, cache_hit_before = self.analyze_fen(fen_before, depth=depth, multipv=multipv)
        after_lines, cache_hit_after = self.analyze_fen(fen_after, depth=depth, multipv=1)

        best = before_lines[0] if before_lines else None
        best_move_uci = best.move_uci if best else None
        best_move_san = best.move_san if best else None
        pv_san = best.pv_san if best else None
        played_is_best = bool(best_move_uci and best_move_uci == played_uci)

        board_before = chess.Board(fen_before)
        board_after = chess.Board(fen_after)

        eval_before_cp = best.eval_cp if best else 0
        mate_before = best.mate if best else None

        after_best = after_lines[0] if after_lines else None
        eval_after_cp = after_best.eval_cp if after_best else 0
        mate_after = after_best.mate if after_best else None

        # Recompute user-POV from raw board turn for safety when lines came from cache.
        if best is not None:
            eval_before_cp = best.eval_cp
        if after_best is not None:
            eval_after_cp = after_best.eval_cp

        log_verbose(
            "evaluate_user_move",
            fen_before=fen_before.split()[0] if fen_before else "",
            depth=depth,
            multipv=multipv,
            eval_before_cp=eval_before_cp,
            eval_after_cp=eval_after_cp,
            best_move_uci=best_move_uci,
            played_uci=played_uci,
            played_is_best=played_is_best,
            cache_hit_before=cache_hit_before,
            cache_hit_after=cache_hit_after,
            side_to_move="w" if board_before.turn == chess.WHITE else "b",
            after_side="w" if board_after.turn == chess.WHITE else "b",
        )

        return EngineEvaluation(
            eval_before_cp=eval_before_cp,
            eval_after_cp=eval_after_cp,
            mate_before=mate_before,
            mate_after=mate_after,
            best_move_uci=best_move_uci,
            best_move_san=best_move_san,
            principal_variation=pv_san,
            candidates=tuple(before_lines),
            depth=depth,
            multipv=multipv,
            played_is_best=played_is_best,
            cache_hit_before=cache_hit_before,
            cache_hit_after=cache_hit_after,
        )

    def analyze_fen(
        self,
        fen: str,
        *,
        depth: int,
        multipv: int,
    ) -> tuple[list[CandidateLine], bool]:
        if self._cache is not None:
            cached = self._cache.get(
                fen=fen,
                engine_name=self._engine_name,
                engine_version=self._engine_version,
                depth=depth,
                multipv=multipv,
                analysis_version=self._analysis_version,
            )
            if cached is not None:
                return self._candidates_from_payload(cached), True

        lines = self.analyze_position(chess.Board(fen), depth=depth, multipv=multipv)
        payload = {"candidates": [line.to_dict() for line in lines]}
        if self._cache is not None:
            self._cache.put(
                fen=fen,
                engine_name=self._engine_name,
                engine_version=self._engine_version,
                depth=depth,
                multipv=multipv,
                analysis_version=self._analysis_version,
                result=payload,
            )
        return lines, False

    def analyze_position(
        self,
        board: chess.Board,
        *,
        depth: int,
        multipv: int,
    ) -> list[CandidateLine]:
        if self._engine is None:
            raise EngineFailureError("engine not started")

        try:
            infos = self._engine.analyse(
                board,
                chess.engine.Limit(depth=depth, time=self._timeout),
                multipv=max(1, multipv),
                info=chess.engine.INFO_ALL,
            )
        except chess.engine.EngineTerminatedError as exc:
            raise EngineFailureError(f"engine terminated: {exc}") from exc
        except TimeoutError as exc:
            raise EngineTimeoutError(f"engine timed out after {self._timeout}s") from exc
        except Exception as exc:
            raise EngineFailureError(f"engine analysis failed: {exc}") from exc

        if isinstance(infos, dict):
            infos = [infos]

        lines: list[CandidateLine] = []
        for index, info in enumerate(infos, start=1):
            score = info.get("score")
            if score is None:
                raise EngineFailureError("engine returned no score")

            white_score = score.white()
            cp_raw = white_score.score(mate_score=10_000)
            mate_raw = white_score.mate()
            pv = info.get("pv", [])
            best_move = pv[0] if pv else None
            move_uci = best_move.uci() if best_move else None
            move_san = board.san(best_move) if best_move else None
            pv_san = self._pv_to_san(board, pv)

            eval_cp = score_to_user_cp(
                cp=cp_raw,
                mate=mate_raw,
                user_is_white=self._user_is_white,
                white_to_move=board.turn == chess.WHITE,
            )
            mate = self._user_mate_from_white(mate_raw, self._user_is_white)

            lines.append(
                CandidateLine(
                    rank=index,
                    move_uci=move_uci,
                    move_san=move_san,
                    eval_cp=eval_cp,
                    mate=mate,
                    pv_san=pv_san,
                )
            )

        return lines

    @staticmethod
    def _candidates_from_payload(payload: dict[str, Any]) -> list[CandidateLine]:
        raw = payload.get("candidates") or []
        lines: list[CandidateLine] = []
        for item in raw:
            lines.append(
                CandidateLine(
                    rank=int(item.get("rank", len(lines) + 1)),
                    move_uci=item.get("move_uci"),
                    move_san=item.get("move_san"),
                    eval_cp=int(item.get("eval_cp", 0)),
                    mate=item.get("mate"),
                    pv_san=item.get("pv_san"),
                )
            )
        return lines

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
