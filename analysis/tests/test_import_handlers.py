from unittest.mock import MagicMock, patch

import pytest

from worker.import_handlers import import_games_handler
from worker.jobs import SystemJobRow


def test_import_games_handler_requires_batch_id() -> None:
    job = SystemJobRow(id="job1", user_id="user1", job_type=0, payload={})

    with pytest.raises(ValueError, match="import_batch_id is required"):
        import_games_handler(job)


def test_import_games_handler_passes_access_token_from_payload() -> None:
    job = SystemJobRow(
        id="job1",
        user_id="user1",
        job_type=0,
        payload={"import_batch_id": "batch1", "access_token": "payload-token"},
    )
    conn = MagicMock()
    conn.__enter__.return_value = conn
    conn.__exit__.return_value = False

    with patch("worker.import_handlers.load_config") as load_config:
        load_config.return_value.database_url = "postgresql://example"
        with patch("worker.import_handlers.psycopg.connect", return_value=conn):
            with patch("worker.import_handlers.run_import", return_value={"status": "succeeded"}) as run_import:
                result = import_games_handler(job)

    assert result == {"status": "succeeded"}
    run_import.assert_called_once_with(conn, "batch1", access_token="payload-token")
