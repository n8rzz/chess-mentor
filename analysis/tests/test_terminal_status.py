from worker.import_package.handler import _terminal_status


def test_terminal_status_failed_when_all_fail() -> None:
    assert _terminal_status(imported=0, failed=2, found=2) == "failed"


def test_terminal_status_partial_when_mixed() -> None:
    assert _terminal_status(imported=1, failed=1, found=2) == "partially_succeeded"


def test_terminal_status_partial_when_some_skipped() -> None:
    assert _terminal_status(imported=1, failed=0, found=3) == "partially_succeeded"


def test_terminal_status_succeeded_when_all_imported() -> None:
    assert _terminal_status(imported=3, failed=0, found=3) == "succeeded"


def test_terminal_status_succeeded_when_none_found() -> None:
    assert _terminal_status(imported=0, failed=0, found=0) == "succeeded"
