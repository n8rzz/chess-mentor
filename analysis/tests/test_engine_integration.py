import os
from pathlib import Path

import pytest

from worker.eval_package.engine import StockfishEvaluator

STOCKFISH_PATH = os.environ.get("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")
stockfish_available = Path(STOCKFISH_PATH).is_file()


@pytest.mark.skipif(not stockfish_available, reason="Stockfish binary not available")
def test_stockfish_evaluates_user_move():
    with StockfishEvaluator(
        stockfish_path=STOCKFISH_PATH,
        user_is_white=True,
        engine_name="Stockfish",
        engine_version="16.1",
        analysis_version="1.1.0",
    ) as engine:
        result = engine.evaluate_user_move(
            fen_before="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
            fen_after="rnbqkbnr/pppppppp/8/8/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2",
            played_uci="e7e5",
            depth=10,
            multipv=3,
        )

    assert result.eval_before_cp is not None
    assert result.best_move_uci is not None
    assert result.played_is_best is not None
    assert len(result.candidates) >= 1


@pytest.mark.skipif(not stockfish_available, reason="Stockfish binary not available")
def test_stockfish_multipv_returns_ranked_candidates():
    with StockfishEvaluator(
        stockfish_path=STOCKFISH_PATH,
        user_is_white=True,
        engine_name="Stockfish",
        engine_version="16.1",
        analysis_version="1.1.0",
    ) as engine:
        lines = engine.analyze_position(
            __import__("chess").Board(),
            depth=8,
            multipv=3,
        )

    assert len(lines) == 3
    assert lines[0].rank == 1
    assert lines[0].move_uci is not None
