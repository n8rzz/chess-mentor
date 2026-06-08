from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class CandidateEventData:
    event_type: int
    severity: float
    confidence: float
    metadata: dict[str, Any]
