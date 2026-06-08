from __future__ import annotations

import logging
from typing import Any

import psycopg

from worker.config import load_config
from worker.eval_package.classifier import (
    centipawn_loss,
    classify_move,
    evaluation_metadata,
)
from worker.eval_package.constants import USER_COLOR
from worker.eval_package.detectors import run_detectors
from worker.eval_package.engine import StockfishEvaluator
from worker.eval_package.errors import AnalysisError
from worker.eval_package.positions import MovePosition, generate_positions
from worker.eval_package.repository import AnalysisRepository, StoredMove

logger = logging.getLogger(__name__)


def run_analysis(conn: psycopg.Connection, analysis_run_id: str, game_id: str) -> dict[str, Any]:
    repo = AnalysisRepository(conn)
    context = repo.load_context(analysis_run_id, game_id)
    repo.mark_running(analysis_run_id)

    try:
        return _analyze(conn, repo, context)
    except AnalysisError as exc:
        repo.mark_failed(
            analysis_run_id,
            error_message=exc.message,
            error_details=exc.to_details(),
        )
        raise


def _analyze(conn: psycopg.Connection, repo: AnalysisRepository, context) -> dict[str, Any]:
    positions = generate_positions(context.pgn, user_color=context.user_color)

    with conn.transaction():
        if not repo.game_has_moves(context.game_id):
            repo.insert_moves(context.game_id, positions)

        stored_moves = repo.load_moves(context.game_id)
        position_by_ply = {position.parsed.ply: position for position in positions}

        user_moves_evaluated = 0
        events_detected = 0
        config = load_config()
        user_is_white = context.user_color == USER_COLOR["white"]

        with StockfishEvaluator(
            stockfish_path=config.stockfish_path,
            depth=context.depth,
            user_is_white=user_is_white,
        ) as engine:
            engine_version = engine.engine_version

            for move in stored_moves:
                position = position_by_ply.get(move.ply)
                if position is None:
                    raise ValueError(f"missing position for ply {move.ply}")

                evaluation = None
                cpl = None

                if move.played_by_user:
                    evaluation = engine.evaluate_user_move(
                        fen_before=move.fen_before,
                        fen_after=move.fen_after,
                        played_uci=move.uci,
                    )
                    cpl = centipawn_loss(evaluation.eval_before_cp, evaluation.eval_after_cp)
                    classification = classify_move(cpl)
                    metadata = evaluation_metadata(time_class=context.time_class, cpl=cpl)

                    repo.insert_move_evaluation(
                        analysis_run_id=context.analysis_run_id,
                        game_id=context.game_id,
                        move_id=move.id,
                        depth=context.depth,
                        eval_before_cp=evaluation.eval_before_cp,
                        eval_after_cp=evaluation.eval_after_cp,
                        centipawn_loss=cpl,
                        classification=classification,
                        best_move_uci=evaluation.best_move_uci,
                        best_move_san=evaluation.best_move_san,
                        principal_variation=evaluation.principal_variation,
                        mate_before=evaluation.mate_before,
                        mate_after=evaluation.mate_after,
                        metadata=metadata,
                    )
                    user_moves_evaluated += 1

                events = run_detectors(
                    context=context,
                    move=move,
                    position=position,
                    evaluation=evaluation,
                    cpl=cpl,
                )
                for event in events:
                    repo.insert_candidate_event(
                        analysis_run_id=context.analysis_run_id,
                        game_id=context.game_id,
                        move_id=move.id,
                        event_type=event.event_type,
                        severity=event.severity,
                        confidence=event.confidence,
                        metadata=event.metadata,
                    )
                    events_detected += 1

        repo.mark_succeeded(
            context.analysis_run_id,
            metadata_patch={
                "engine_version_observed": engine_version,
                "moves_parsed": len(stored_moves),
                "user_moves_evaluated": user_moves_evaluated,
                "events_detected": events_detected,
            },
        )

    return {
        "analysis_run_id": context.analysis_run_id,
        "game_id": context.game_id,
        "status": "succeeded",
        "moves_parsed": len(stored_moves),
        "user_moves_evaluated": user_moves_evaluated,
        "events_detected": events_detected,
    }
