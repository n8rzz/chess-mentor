import pytest

from worker.import_handlers import import_games_handler
from worker.jobs import SystemJobRow


def test_import_games_handler_requires_batch_id() -> None:
    job = SystemJobRow(id="job1", user_id="user1", job_type=0, payload={})

    with pytest.raises(ValueError, match="import_batch_id is required"):
        import_games_handler(job)
