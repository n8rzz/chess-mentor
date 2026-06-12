"""Integer enums and tunable thresholds for training plan generation."""

from worker.weakness_package.constants import IMPROVING_THRESHOLD, MANAGED_THRESHOLD, WEAKNESS_THEME

PLAN_DURATION_DAYS = 14

DAILY_PERSONAL_REVIEWS = 1
DAILY_THEME_PUZZLES = 5
DAILY_PLAY_GAMES = 1
DAILY_HABIT_EXERCISES = 1

ASSIGNMENTS_PER_DAY = (
    DAILY_PERSONAL_REVIEWS
    + DAILY_THEME_PUZZLES
    + DAILY_PLAY_GAMES
    + DAILY_HABIT_EXERCISES
)

ASSIGNMENT_TYPE = {
    "personal_position_review": 0,
    "theme_puzzle": 1,
    "play_game": 2,
    "habit_exercise": 3,
}

ASSIGNMENT_STATUS = {
    "pending": 0,
}

PLAN_STATUS = {
    "recommended": 0,
    "active": 1,
}

PUZZLE_SOURCE = {
    "curated": 0,
}

THEME_LABELS = {
    theme: key.replace("_", " ").title()
    for key, theme in WEAKNESS_THEME.items()
}

THEME_BY_INTEGER = {value: key for key, value in WEAKNESS_THEME.items()}

HABIT_PROMPTS = {
    "hanging_pieces": "Before every move ask: What is attacked?",
    "missed_tactics": "Before every move ask: Do I have a forcing move?",
    "ignored_threats": "Before every move ask: What is my opponent threatening?",
    "opening_development": "Before every move ask: Am I developing pieces efficiently?",
    "king_safety": "Before every move ask: Is my king safe?",
    "bad_trades": "Before every capture ask: Is this trade favorable?",
    "pawn_structure": "Before every pawn move ask: How does this affect my structure?",
    "endgame_technique": "Before every move ask: What is the winning technique here?",
    "time_pressure": "Before every move ask: What is the one critical thing to calculate?",
}

DEFAULT_HABIT_PROMPT = "Before every move ask: What is the best candidate move?"

PLAY_GAME_PROMPT = "Play 1 rapid game focusing on {theme_label}."

PERSONAL_REVIEW_PROMPT = "Review your mistake from this game position and find the best move."
