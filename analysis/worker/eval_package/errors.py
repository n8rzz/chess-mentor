from __future__ import annotations


class AnalysisError(Exception):
    code: str = "analysis_error"

    def __init__(self, message: str, *, context: dict | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.context = context or {}

    def to_details(self) -> dict:
        return {"code": self.code, "context": self.context}


class InvalidPgnError(AnalysisError):
    code = "invalid_pgn"


class EngineTimeoutError(AnalysisError):
    code = "engine_timeout"


class EngineFailureError(AnalysisError):
    code = "engine_failure"


class PositionReconstructionError(AnalysisError):
    code = "position_reconstruction_failure"
