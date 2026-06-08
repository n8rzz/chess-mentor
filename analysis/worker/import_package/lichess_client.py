from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import httpx

from worker.import_package.constants import PERF_TO_TIME_CLASS, PROVIDER, RESULT, TIME_CLASS, USER_COLOR


class LichessApiError(Exception):
    pass


class LichessAuthError(LichessApiError):
    pass


@dataclass(frozen=True)
class LichessGame:
    raw: dict[str, Any]


class LichessClient:
    BASE_URL = "https://lichess.org"

    def __init__(self, access_token: str, *, timeout: float = 30.0, client: httpx.Client | None = None) -> None:
        self._access_token = access_token
        self._timeout = timeout
        self._client = client

    def fetch_games(
        self,
        username: str,
        *,
        since_ms: int,
        until_ms: int,
        max_games: int,
        perf_types: list[str],
    ) -> list[LichessGame]:
        params = {
            "since": since_ms,
            "until": until_ms,
            "max": max_games,
            "perfType": ",".join(perf_types),
            "pgnInJson": "true",
            "clocks": "true",
            "opening": "true",
        }
        url = f"{self.BASE_URL}/api/games/user/{username}"
        headers = {
            "Authorization": f"Bearer {self._access_token}",
            "Accept": "application/x-ndjson",
        }

        if self._client is not None:
            response = self._client.get(url, params=params, headers=headers)
        else:
            with httpx.Client(timeout=self._timeout) as client:
                response = client.get(url, params=params, headers=headers)

        if response.status_code == 401:
            raise LichessAuthError("Lichess access token is invalid or expired")
        if response.status_code >= 400:
            raise LichessApiError(f"Lichess API request failed ({response.status_code})")

        games: list[LichessGame] = []
        for line in response.text.splitlines():
            line = line.strip()
            if not line:
                continue
            import json

            games.append(LichessGame(raw=json.loads(line)))
        return games


def normalize_lichess_game(game: LichessGame, *, account_username: str) -> dict[str, Any]:
    raw = game.raw
    provider_game_id = raw.get("id")
    if not provider_game_id:
        raise ValueError("missing game id")

    pgn = raw.get("pgn")
    if not pgn:
        raise ValueError("missing pgn")

    created_at_ms = raw.get("createdAt")
    if created_at_ms is None:
        raise ValueError("missing createdAt")
    played_at = datetime.fromtimestamp(created_at_ms / 1000, tz=timezone.utc)

    user_color_key = _user_color(raw, account_username)
    result_key = _result(raw, user_color_key)

    perf = raw.get("perf") or raw.get("speed") or "unknown"
    time_class = PERF_TO_TIME_CLASS.get(perf, TIME_CLASS["unknown"])

    user_rating, opponent_rating, opponent_username = _ratings(raw, user_color_key)
    opening_name, opening_eco = _opening(raw)
    time_control = _time_control(raw)

    return {
        "provider": PROVIDER["lichess"],
        "provider_game_id": provider_game_id,
        "pgn": pgn,
        "played_at": played_at,
        "user_color": USER_COLOR[user_color_key],
        "result": RESULT[result_key],
        "time_class": time_class,
        "time_control": time_control,
        "opening_name": opening_name,
        "opening_eco": opening_eco,
        "user_rating": user_rating,
        "opponent_rating": opponent_rating,
        "opponent_username": opponent_username,
        "metadata": {},
    }


def _user_color(raw: dict[str, Any], account_username: str) -> str:
    players = raw.get("players") or {}
    account_username_lower = account_username.lower()

    white = _player_username(players.get("white") or {})
    black = _player_username(players.get("black") or {})

    if white and white.lower() == account_username_lower:
        return "white"
    if black and black.lower() == account_username_lower:
        return "black"

    raise ValueError("account username not found in game players")


def _player_username(player: dict[str, Any]) -> str | None:
    user = player.get("user") or {}
    return user.get("name") or user.get("id")


def _result(raw: dict[str, Any], user_color: str) -> str:
    winner = raw.get("winner")
    if winner is None:
        return "draw"
    if winner == user_color:
        return "win"
    return "loss"


def _ratings(raw: dict[str, Any], user_color: str) -> tuple[int | None, int | None, str | None]:
    players = raw.get("players") or {}
    user_player = players.get(user_color) or {}
    opponent_color = "black" if user_color == "white" else "white"
    opponent_player = players.get(opponent_color) or {}

    user_rating = user_player.get("rating")
    opponent_rating = opponent_player.get("rating")
    opponent_username = _player_username(opponent_player)
    return user_rating, opponent_rating, opponent_username


def _opening(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    opening = raw.get("opening") or {}
    return opening.get("name"), opening.get("eco")


def _time_control(raw: dict[str, Any]) -> str | None:
    clock = raw.get("clock") or {}
    initial = clock.get("initial")
    increment = clock.get("increment")
    if initial is None or increment is None:
        return None
    return f"{initial}+{increment}"
