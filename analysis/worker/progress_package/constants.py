"""Integer enums and snapshot kinds for progress tracking."""

from worker.eval_package.constants import TIME_CLASS
from worker.weakness_package.constants import (
    JOB_STATUS_CLAIMED,
    JOB_STATUS_PENDING,
    JOB_STATUS_PROCESSING,
)

JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS = 4

SNAPSHOT_KIND_RATING = "rating"
SNAPSHOT_KIND_PERFORMANCE = "performance"
SNAPSHOT_KIND_WEAKNESS = "weakness"
SNAPSHOT_KIND_TRAINING = "training"

# Rails `TrainingPlan` statuses included in `current_for`.
PLAN_STATUS_CURRENT = {
    "active": 1,
    "paused": 2,
    "improving": 3,
    "managed": 4,
}

# Weakness cycles tracked on the dashboard weakness trend chart.
CYCLE_STATUS_TRACKED = {
    "active": 1,
    "improving": 2,
    "managed": 3,
}

ASSIGNMENT_STATUS_COMPLETED = 1

RATING_TIME_CLASSES = (
    TIME_CLASS["bullet"],
    TIME_CLASS["blitz"],
    TIME_CLASS["rapid"],
    TIME_CLASS["classical"],
)

ANALYSIS_RUN_SUCCEEDED = 2

__all__ = [
    "ANALYSIS_RUN_SUCCEEDED",
    "ASSIGNMENT_STATUS_COMPLETED",
    "CYCLE_STATUS_TRACKED",
    "JOB_STATUS_CLAIMED",
    "JOB_STATUS_PENDING",
    "JOB_STATUS_PROCESSING",
    "JOB_TYPE_UPDATE_PROGRESS_SNAPSHOTS",
    "PLAN_STATUS_CURRENT",
    "RATING_TIME_CLASSES",
    "SNAPSHOT_KIND_PERFORMANCE",
    "SNAPSHOT_KIND_RATING",
    "SNAPSHOT_KIND_TRAINING",
    "SNAPSHOT_KIND_WEAKNESS",
    "TIME_CLASS",
]
