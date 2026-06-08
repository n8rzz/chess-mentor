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
        depth=10,
        user_is_white=True,
    ) as engine:
        result = engine.evaluate_user_move(
            fen_before="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
            fen_after="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
            played_uci="e7e5",
        )

    assert result.eval_before_cp is not None
    assert result.best_move_uci is not None
