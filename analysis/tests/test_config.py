from __future__ import annotations

import socket
from unittest.mock import patch

from worker.config import load_config


def test_load_config_uses_worker_id_from_environment(monkeypatch):
    monkeypatch.setenv("DATABASE_HOST", "localhost")
    monkeypatch.setenv("DATABASE_USERNAME", "chess_mentor")
    monkeypatch.setenv("DATABASE_PASSWORD", "chess_mentor")
    monkeypatch.setenv("DATABASE_NAME", "chess_mentor_development")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    monkeypatch.setenv("STOCKFISH_PATH", "/usr/games/stockfish")
    monkeypatch.setenv("WORKER_ID", "worker-test")

    config = load_config()

    assert config.worker_id == "worker-test"


def test_load_config_falls_back_to_hostname_when_worker_id_is_empty(monkeypatch):
    monkeypatch.setenv("DATABASE_HOST", "localhost")
    monkeypatch.setenv("DATABASE_USERNAME", "chess_mentor")
    monkeypatch.setenv("DATABASE_PASSWORD", "chess_mentor")
    monkeypatch.setenv("DATABASE_NAME", "chess_mentor_development")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    monkeypatch.setenv("STOCKFISH_PATH", "/usr/games/stockfish")
    monkeypatch.setenv("WORKER_ID", "")

    with patch("worker.config.socket.gethostname", return_value="container-abc"):
        config = load_config()

    assert config.worker_id == "container-abc"


def test_load_config_falls_back_to_hostname_when_worker_id_is_unset(monkeypatch):
    monkeypatch.setenv("DATABASE_HOST", "localhost")
    monkeypatch.setenv("DATABASE_USERNAME", "chess_mentor")
    monkeypatch.setenv("DATABASE_PASSWORD", "chess_mentor")
    monkeypatch.setenv("DATABASE_NAME", "chess_mentor_development")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    monkeypatch.setenv("STOCKFISH_PATH", "/usr/games/stockfish")
    monkeypatch.delenv("WORKER_ID", raising=False)

    with patch("worker.config.socket.gethostname", return_value=socket.gethostname()):
        config = load_config()

    assert config.worker_id == socket.gethostname()
