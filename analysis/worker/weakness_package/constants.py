"""Integer enums and tunable thresholds for the weakness classifier.

All integer values mirror the Rails contract (`WeaknessThemeable`, `WeaknessCycle`,
`WeaknessEvent`, `SystemJob`) so Python writers and the UI read the same semantics.

Usage:
    from worker.weakness_package.constants import WEAKNESS_THEME, DETECTION_WINDOW_GAMES

    theme = WEAKNESS_THEME["missed_tactics"]
    if occurrences >= MIN_OCCURRENCES_FOR_ACTIVE:
        status = CYCLE_STATUS["active"]
"""

from worker.eval_package.constants import CPL_THRESHOLDS

# Maps weakness theme names to integers persisted on `weakness_events.primary_theme`,
# `weakness_events.secondary_theme`, and `weakness_cycles.theme`.
# Use string keys in application logic; write integers to SQL.
# Must stay aligned with `WeaknessThemeable::THEMES` in Rails.
WEAKNESS_THEME = {
    "hanging_pieces": 0,
    "missed_tactics": 1,
    "ignored_threats": 2,
    "opening_development": 3,
    "king_safety": 4,
    "bad_trades": 5,
    "pawn_structure": 6,
    "endgame_technique": 7,
    "time_pressure": 8,
}

# Game phase integers for `weakness_events.phase`.
# Derived from move number and endgame detector signals in `theme_rules.py`.
# Must match `GamePhaseable::PHASES` in Rails.
GAME_PHASE = {
    "opening": 0,
    "middlegame": 1,
    "endgame": 2,
}

# Lifecycle states for `weakness_cycles.status`.
# Transitions are computed in `cycles.py` from occurrence counts and improvement %.
# `active` cycles are eligible for training-plan targeting (Milestone 6).
CYCLE_STATUS = {
    "detected": 0,
    "active": 1,
    "improving": 2,
    "managed": 3,
    "archived": 4,
}

# `SystemJob#job_type` value for weakness classification.
# Used when enqueueing after analysis (`repository.enqueue_classification_if_needed`).
JOB_TYPE_CLASSIFY_WEAKNESSES = 2

# Non-terminal `SystemJob#status` values checked when deduping classify jobs.
# Skip enqueue if the user already has a classify job in one of these states.
JOB_STATUS_PENDING = 0
JOB_STATUS_CLAIMED = 1
JOB_STATUS_PROCESSING = 2

# Detection window: only games within this lookback are considered.
# `repository.load_window_artifacts` applies both limits (most recent N games
# among those played within the last N days).
DETECTION_WINDOW_GAMES = 30
DETECTION_WINDOW_DAYS = 30

# Recurring-pattern activation: a cycle stays `detected` until both thresholds are met.
# Prevents single-game mistakes from becoming official weaknesses.
# Tune these to make weakness detection more or less sensitive.
MIN_OCCURRENCES_FOR_ACTIVE = 3
MIN_GAMES_FOR_ACTIVE = 2

# Frequency reduction thresholds for lifecycle promotion (fractions, not percentages).
# Compared in `cycles.transition_status_for_improvement` against
# `1 - (current_occurrences / baseline_occurrences)`.
IMPROVING_THRESHOLD = 0.30
MANAGED_THRESHOLD = 0.75

# Last full move number treated as opening for `opening_development` vs `king_safety`.
# Moves at or below this limit with delayed-castling signals map to opening development.
OPENING_MOVE_LIMIT = 15

# Minimum centipawn loss for a move to count as a missed tactic (~1.5 pawns in MVP).
# Applied in `theme_rules._matches_missed_tactics` alongside tactical candidate events.
TACTICAL_VALUE_MIN_CPL = 75

# Minimum material lost (in piece-value units) for a capture sequence to count as a bad trade.
# Used with eval worsening in `theme_rules._matches_bad_trades`.
BAD_TRADE_MIN_MATERIAL_LOST = 1

# Standalone time-pressure weakness: mistake rate under clock pressure must exceed
# baseline rate by this multiplier AND meet `TIME_PRESSURE_MIN_MISTAKES`.
# Evaluated in `aggregator._standalone_time_pressure_qualifies`.
TIME_PRESSURE_MISTAKE_RATE_MULTIPLIER = 1.5
TIME_PRESSURE_MIN_MISTAKES = 3

# Weights for the cycle severity formula in `aggregator.compute_cycle_severity`.
# Components: occurrence (frequency), impact (avg event severity), recency (decay).
# Values should sum to 1.0.
SEVERITY_WEIGHTS = {
    "occurrence": 0.35,
    "impact": 0.40,
    "recency": 0.25,
}

# Half-life for exponential recency decay in severity scoring (days).
# Recent weakness events contribute more to `current_severity` than older ones.
RECENCY_HALF_LIFE_DAYS = 10

# Re-exported CPL cutoffs from the evaluation engine for theme rule consistency.
# `INACCURACY_CPL`: minimum eval loss for positional/threat themes.
# `MISTAKE_CPL`: used as an alternate missed-tactic signal when CPL is very high.
INACCURACY_CPL = CPL_THRESHOLDS["inaccuracy"]
MISTAKE_CPL = CPL_THRESHOLDS["mistake"]
