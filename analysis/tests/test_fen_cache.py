from worker.eval_package.fen_cache import EnginePositionCache, normalize_position_key


def test_normalize_position_key_drops_move_counters():
    fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    assert normalize_position_key(fen) == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3"


def test_engine_position_cache_round_trip(db_conn):
    cache = EnginePositionCache(db_conn)
    fen = "8/8/8/8/8/8/4P3/4K2k w - - 0 1"
    analysis_version = "1.1.0-cache-test"
    payload = {
        "candidates": [
            {
                "rank": 1,
                "move_uci": "e2e4",
                "move_san": "e4",
                "eval_cp": 25,
                "mate": None,
                "pv_san": "e4",
            }
        ]
    }

    assert (
        cache.get(
            fen=fen,
            engine_name="Stockfish",
            engine_version="16.1",
            depth=14,
            multipv=3,
            analysis_version=analysis_version,
        )
        is None
    )
    assert cache.misses == 1

    cache.put(
        fen=fen,
        engine_name="Stockfish",
        engine_version="16.1",
        depth=14,
        multipv=3,
        analysis_version=analysis_version,
        result=payload,
    )

    loaded = cache.get(
        fen=fen,
        engine_name="Stockfish",
        engine_version="16.1",
        depth=14,
        multipv=3,
        analysis_version=analysis_version,
    )
    assert loaded is not None
    assert loaded["candidates"][0]["move_uci"] == "e2e4"
    assert cache.hits == 1

    assert (
        cache.get(
            fen=fen,
            engine_name="Stockfish",
            engine_version="16.1",
            depth=14,
            multipv=3,
            analysis_version="1.0.0",
        )
        is None
    )
