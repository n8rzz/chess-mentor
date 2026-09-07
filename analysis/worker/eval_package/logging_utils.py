from __future__ import annotations

import logging
import os

logger = logging.getLogger("worker.eval")


def analysis_verbose() -> bool:
    return os.environ.get("ANALYSIS_VERBOSE", "").strip().lower() in {"1", "true", "yes", "on"}


def log_run(message: str, **fields: object) -> None:
    logger.info(_format("analysis.run", message, fields))


def log_verbose(message: str, **fields: object) -> None:
    if not analysis_verbose():
        return
    logger.info(_format("analysis.verbose", message, fields))


def log_cache(message: str, **fields: object) -> None:
    if analysis_verbose():
        logger.info(_format("analysis.cache", message, fields))
    else:
        logger.debug(_format("analysis.cache", message, fields))


def log_enqueue_skip(message: str, **fields: object) -> None:
    logger.info(_format("analysis.enqueue_skip", message, fields))


def _format(prefix: str, message: str, fields: dict[str, object]) -> str:
    if not fields:
        return f"{prefix} {message}"
    rendered = " ".join(f"{key}={_stringify(value)}" for key, value in fields.items())
    return f"{prefix} {message} {rendered}"


def _stringify(value: object) -> str:
    if isinstance(value, str):
        if " " in value or not value:
            return repr(value)
        return value
    return repr(value)
