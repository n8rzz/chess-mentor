from __future__ import annotations

import logging
import time
from typing import Any

import psycopg

from worker.config import load_config
from worker.eval_package.classifier import (
    centipawn_loss,
    classify_move,
    evaluation_metadata,
)
from worker.eval_package.constants import ANALYSIS_PHASE, ANALYSIS_RUN_STATUS, PHASE_CLASSIFIER_VERSION, USER_COLOR
from worker.eval_package.critical import assess_criticality, critical_event_payload
from worker.eval_package.detectors import run_detectors
from worker.eval_package.detectors.types import AnalysisEventData
from worker.eval_package.engine import StockfishEvaluator
from worker.eval_package.errors import AnalysisError
from worker.eval_package.fen_cache import EnginePositionCache
from worker.eval_package.logging_utils import log_run, log_verbose
from worker.eval_package.positions import generate_positions
from worker.eval_package.repository import AnalysisRepository
from worker.metrics_package.repository import persist_game_metrics
from worker.weakness_package.repository import PatternRepository

logger = logging.getLogger(__name__)


def run_analysis(conn: psycopg.Connection, analysis_run_id: str, game_id: str) -> dict[str, Any]:
    repo = AnalysisRepository(conn)
    context = repo.load_context(analysis_run_id, game_id)

    if repo.analysis_run_status(analysis_run_id) == ANALYSIS_RUN_STATUS["succeeded"]:
        logger.info("Analysis run already succeeded analysis_run_id=%s", analysis_run_id)
        return repo.load_succeeded_summary(analysis_run_id, game_id)

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
    started = time.monotonic()
    positions = generate_positions(context.pgn, user_color=context.user_color)
    cache = EnginePositionCache(conn)

    with conn.transaction():
        # Upsert moves and refresh phase classification on every analysis.
        repo.insert_moves(context.game_id, positions)

        stored_moves = repo.load_moves(context.game_id)
        position_by_ply = {position.parsed.ply: position for position in positions}
        user_is_white = context.user_color == USER_COLOR["white"]
        config = load_config()

        log_run(
            "start",
            analysis_run_id=context.analysis_run_id,
            game_id=context.game_id,
            depth_scan=context.depth,
            depth_critical=context.depth_critical,
            multipv=context.multipv,
            analysis_version=context.analysis_version,
            user_moves=sum(1 for move in stored_moves if move.played_by_user),
        )

        user_moves_evaluated = 0
        critical_count = 0
        pass2_count = 0
        evaluated: dict[str, dict[str, Any]] = {}

        repo.set_phase(context.analysis_run_id, ANALYSIS_PHASE["scan"])

        with StockfishEvaluator(
            stockfish_path=config.stockfish_path,
            user_is_white=user_is_white,
            engine_name=context.engine_name,
            engine_version=context.engine_version,
            analysis_version=context.analysis_version,
            cache=cache,
        ) as engine:
            engine_version = engine.engine_version_observed

            for move in stored_moves:
                position = position_by_ply.get(move.ply)
                if position is None:
                    raise ValueError(f"missing position for ply {move.ply}")
                if not move.played_by_user:
                    continue

                stored = repo.load_move_evaluation(context.analysis_run_id, move.id)
                if stored is not None:
                    evaluation, cpl, critical_position, criticality_score = stored
                    metadata = evaluation_metadata(time_class=context.time_class, cpl=cpl)
                    if evaluation.played_is_best is not None:
                        metadata["played_is_best"] = evaluation.played_is_best
                    assessment = None
                    if critical_position:
                        assessment = assess_criticality(
                            context=context,
                            move=move,
                            position=position,
                            evaluation=evaluation,
                            cpl=cpl,
                        )
                else:
                    evaluation = engine.evaluate_user_move(
                        fen_before=move.fen_before,
                        fen_after=move.fen_after,
                        played_uci=move.uci,
                        depth=context.depth,
                        multipv=context.multipv,
                    )
                    cpl = centipawn_loss(evaluation.eval_before_cp, evaluation.eval_after_cp)
                    classification = classify_move(cpl)
                    metadata = evaluation_metadata(time_class=context.time_class, cpl=cpl)
                    metadata.update(
                        {
                            "played_uci": move.uci,
                            "played_is_best": evaluation.played_is_best,
                            "pass": 1,
                            "multipv": context.multipv,
                            "scan_depth": context.depth,
                            "scan_eval_before_cp": evaluation.eval_before_cp,
                            "scan_eval_after_cp": evaluation.eval_after_cp,
                            "scan_centipawn_loss": cpl,
                            "scan_best_move_uci": evaluation.best_move_uci,
                        }
                    )
                    assessment = assess_criticality(
                        context=context,
                        move=move,
                        position=position,
                        evaluation=evaluation,
                        cpl=cpl,
                    )
                    critical_position = assessment.critical_position
                    criticality_score = assessment.criticality_score
                    metadata["critical_reasons"] = list(assessment.reasons)
                    metadata["candidate_gap_cp"] = assessment.candidate_gap_cp

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
                        candidates=[line.to_dict() for line in evaluation.candidates],
                        critical_position=critical_position,
                        criticality_score=criticality_score,
                        multipv=context.multipv,
                    )

                user_moves_evaluated += 1
                if critical_position:
                    critical_count += 1

                gap = None
                if assessment is not None:
                    gap = assessment.candidate_gap_cp
                elif len(evaluation.candidates) >= 2:
                    gap = evaluation.candidates[0].eval_cp - evaluation.candidates[1].eval_cp

                log_verbose(
                    "pass1",
                    ply=move.ply,
                    san=move.san,
                    cpl=cpl,
                    critical=critical_position,
                    criticality_score=criticality_score,
                    candidate_gap_cp=gap,
                    cache_hit_before=evaluation.cache_hit_before,
                    cache_hit_after=evaluation.cache_hit_after,
                )

                evaluated[move.id] = {
                    "move": move,
                    "position": position,
                    "evaluation": evaluation,
                    "cpl": cpl,
                    "critical_position": critical_position,
                    "criticality_score": criticality_score,
                    "metadata": metadata,
                    "assessment": assessment,
                }

            repo.set_phase(
                context.analysis_run_id,
                ANALYSIS_PHASE["deepen"],
                critical_positions=critical_count,
            )

            for move_id, payload in evaluated.items():
                if not payload["critical_position"]:
                    continue
                if payload["evaluation"].depth == context.depth_critical:
                    continue

                move = payload["move"]
                evaluation = engine.evaluate_user_move(
                    fen_before=move.fen_before,
                    fen_after=move.fen_after,
                    played_uci=move.uci,
                    depth=context.depth_critical,
                    multipv=context.multipv,
                )
                cpl = centipawn_loss(evaluation.eval_before_cp, evaluation.eval_after_cp)
                classification = classify_move(cpl)
                metadata = dict(payload["metadata"])
                metadata.update(
                    {
                        "played_uci": move.uci,
                        "played_is_best": evaluation.played_is_best,
                        "pass": 2,
                        "multipv": context.multipv,
                        "scan_depth": metadata.get("scan_depth", context.depth),
                        "critical_depth": context.depth_critical,
                    }
                )
                assessment = assess_criticality(
                    context=context,
                    move=move,
                    position=payload["position"],
                    evaluation=evaluation,
                    cpl=cpl,
                )
                metadata["critical_reasons"] = list(assessment.reasons)
                metadata["candidate_gap_cp"] = assessment.candidate_gap_cp

                repo.update_move_evaluation(
                    analysis_run_id=context.analysis_run_id,
                    move_id=move_id,
                    depth=context.depth_critical,
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
                    candidates=[line.to_dict() for line in evaluation.candidates],
                    critical_position=True,
                    criticality_score=assessment.criticality_score,
                )

                pass2_count += 1
                log_verbose(
                    "pass2",
                    ply=move.ply,
                    san=move.san,
                    cpl=cpl,
                    criticality_score=assessment.criticality_score,
                    reasons=",".join(assessment.reasons),
                    cache_hit_before=evaluation.cache_hit_before,
                    multipv_summary=[
                        f"{line.rank}:{line.move_uci}:{line.eval_cp}" for line in evaluation.candidates
                    ],
                )

                payload["evaluation"] = evaluation
                payload["cpl"] = cpl
                payload["criticality_score"] = assessment.criticality_score
                payload["metadata"] = metadata
                payload["assessment"] = assessment

            repo.set_phase(
                context.analysis_run_id,
                ANALYSIS_PHASE["detect"],
                pass2_deepened=pass2_count,
            )

            events_detected = 0
            for move in stored_moves:
                position = position_by_ply.get(move.ply)
                if position is None:
                    raise ValueError(f"missing position for ply {move.ply}")

                if repo.move_has_analysis_events(context.analysis_run_id, move.id):
                    continue

                evaluation = None
                cpl = None
                assessment = None
                if move.played_by_user and move.id in evaluated:
                    evaluation = evaluated[move.id]["evaluation"]
                    cpl = evaluated[move.id]["cpl"]
                    assessment = evaluated[move.id]["assessment"]
                    if assessment is None and evaluated[move.id]["critical_position"]:
                        assessment = assess_criticality(
                            context=context,
                            move=move,
                            position=position,
                            evaluation=evaluation,
                            cpl=cpl,
                        )

                events = run_detectors(
                    context=context,
                    move=move,
                    position=position,
                    evaluation=evaluation,
                    cpl=cpl,
                )
                if assessment is not None and assessment.critical_position:
                    critical_payload = critical_event_payload(assessment)
                    events.append(
                        AnalysisEventData(
                            event_type=critical_payload["event_type"],
                            severity=critical_payload["severity"],
                            confidence=critical_payload["confidence"],
                            metadata=critical_payload["metadata"],
                        )
                    )

                for event in events:
                    repo.insert_analysis_event(
                        analysis_run_id=context.analysis_run_id,
                        game_id=context.game_id,
                        move_id=move.id,
                        event_type=event.event_type,
                        severity=event.severity,
                        confidence=event.confidence,
                        metadata=event.metadata,
                    )
                    events_detected += 1

        total_events = repo.count_analysis_events(context.analysis_run_id)
        duration_ms = int((time.monotonic() - started) * 1000)
        repo.mark_succeeded(
            context.analysis_run_id,
            metadata_patch={
                "phase": ANALYSIS_PHASE["complete"],
                "engine_version_observed": engine_version,
                "phase_classifier_version": PHASE_CLASSIFIER_VERSION,
                "moves_parsed": len(stored_moves),
                "user_moves_evaluated": user_moves_evaluated,
                "events_detected": total_events,
                "critical_positions": critical_count,
                "pass2_deepened": pass2_count,
                "depth_scan": context.depth,
                "depth_critical": context.depth_critical,
                "multipv": context.multipv,
                "cache_hits": cache.hits,
                "cache_misses": cache.misses,
                "duration_ms": duration_ms,
            },
        )

        PatternRepository(conn).enqueue_classification_if_needed(context.user_id)
        persist_game_metrics(conn, context.analysis_run_id)

    log_run(
        "complete",
        analysis_run_id=context.analysis_run_id,
        game_id=context.game_id,
        user_moves_evaluated=user_moves_evaluated,
        critical_positions=critical_count,
        pass2_deepened=pass2_count,
        cache_hits=cache.hits,
        cache_misses=cache.misses,
        events_detected=total_events,
        duration_ms=int((time.monotonic() - started) * 1000),
    )

    return {
        "analysis_run_id": context.analysis_run_id,
        "game_id": context.game_id,
        "status": "succeeded",
        "moves_parsed": len(stored_moves),
        "user_moves_evaluated": user_moves_evaluated,
        "events_detected": total_events,
        "critical_positions": critical_count,
        "cache_hits": cache.hits,
        "cache_misses": cache.misses,
    }
