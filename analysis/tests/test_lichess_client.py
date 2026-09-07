import json
from pathlib import Path

import httpx
import pytest

from worker.import_package.lichess_client import LichessApiError, LichessAuthError, LichessClient


FIXTURES = Path(__file__).resolve().parent / "fixtures" / "lichess"


def test_fetch_games_parses_ndjson() -> None:
    game = json.loads((FIXTURES / "game.json").read_text())
    body = json.dumps(game) + "\n"

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/api/games/user/testuser")
        assert request.headers["Authorization"] == "Bearer token"
        return httpx.Response(200, text=body)

    transport = httpx.MockTransport(handler)
    http_client = httpx.Client(transport=transport)
    client = LichessClient("token", client=http_client)

    games = client.fetch_games(
        "testuser",
        since_ms=0,
        until_ms=9999999999999,
        max_games=30,
        perf_types=["blitz"],
    )

    assert len(games) == 1
    assert games[0].raw["id"] == "abc123game"


def test_fetch_games_raises_on_401() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(401)

    transport = httpx.MockTransport(handler)
    http_client = httpx.Client(transport=transport)
    client = LichessClient("bad-token", client=http_client)

    with pytest.raises(LichessAuthError):
        client.fetch_games(
            "testuser",
            since_ms=0,
            until_ms=9999999999999,
            max_games=30,
            perf_types=["blitz"],
        )


def test_fetch_games_retries_on_429_with_retry_after() -> None:
    game = json.loads((FIXTURES / "game.json").read_text())
    body = json.dumps(game) + "\n"
    calls = {"count": 0}
    sleeps: list[float] = []

    def handler(_request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        if calls["count"] == 1:
            return httpx.Response(429, headers={"Retry-After": "2"})
        return httpx.Response(200, text=body)

    transport = httpx.MockTransport(handler)
    http_client = httpx.Client(transport=transport)
    client = LichessClient("token", client=http_client, sleep=sleeps.append)

    games = client.fetch_games(
        "testuser",
        since_ms=0,
        until_ms=9999999999999,
        max_games=30,
        perf_types=["blitz"],
    )

    assert len(games) == 1
    assert calls["count"] == 2
    assert sleeps == [2.0]


def test_fetch_games_retries_on_5xx_then_succeeds() -> None:
    game = json.loads((FIXTURES / "game.json").read_text())
    body = json.dumps(game) + "\n"
    calls = {"count": 0}
    sleeps: list[float] = []

    def handler(_request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        if calls["count"] < 3:
            return httpx.Response(503)
        return httpx.Response(200, text=body)

    transport = httpx.MockTransport(handler)
    http_client = httpx.Client(transport=transport)
    client = LichessClient("token", client=http_client, sleep=sleeps.append)

    games = client.fetch_games(
        "testuser",
        since_ms=0,
        until_ms=9999999999999,
        max_games=30,
        perf_types=["blitz"],
    )

    assert len(games) == 1
    assert calls["count"] == 3
    assert sleeps == [1.0, 2.0]


def test_fetch_games_raises_after_exhausted_429_retries() -> None:
    calls = {"count": 0}
    sleeps: list[float] = []

    def handler(_request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        return httpx.Response(429, headers={"Retry-After": "1"})

    transport = httpx.MockTransport(handler)
    http_client = httpx.Client(transport=transport)
    client = LichessClient("token", client=http_client, sleep=sleeps.append)

    with pytest.raises(LichessApiError, match="429"):
        client.fetch_games(
            "testuser",
            since_ms=0,
            until_ms=9999999999999,
            max_games=30,
            perf_types=["blitz"],
        )

    assert calls["count"] == LichessClient.MAX_RETRIES + 1
    assert len(sleeps) == LichessClient.MAX_RETRIES
