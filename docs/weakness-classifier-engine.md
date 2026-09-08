---
title: Weakness classifier engine
last_modified: 2026-09-08
tags:
  - python
  - weaknesses
  - classification
  - weakness-classifier
---

# Weakness classifier engine

The weakness classifier turns evaluation artifacts (`analysis_events`, `move_evaluations`) into player-facing weakness patterns: `pattern_occurrences` and `pattern_cycles`. It runs inside the Python worker when a `classify_patterns` system job is claimed.

Design spec (requirements and non-goals): [planning/weakness-classifier.md](planning/weakness-classifier.md).
Theme detection product contract: [theme-detection-specification.md](theme-detection-specification.md).

**Classifier / taxonomy version:** `1.1.0` (`AnalysisVersions::PATTERN_*` / `weakness_package.constants`).

## End-to-end flow

```mermaid
flowchart TD
    Analyze[analyze_game succeeds] --> Enqueue[enqueue classify_patterns deduped]
    Job[classify_patterns system job] --> Handler[classify_handlers.py]
    Handler --> Run[weakness_package.handler.run_classification]
    Run --> Load[repository.load_window_artifacts]
    Load --> Rules[theme_rules.classify_move multi-label]
    Load --> Episodes[lost_winning + time_pressure passes]
    Rules --> Agg[aggregator.classify_artifacts]
    Episodes --> Agg
    Agg --> Cycles[cycles.build_cycle]
    Cycles --> WE[(pattern_occurrences)]
    Cycles --> WC[(pattern_cycles)]
    WC --> UI[PatternCyclesController]
```

1. After each successful game analysis, the evaluation handler enqueues a deduped `classify_patterns` job for the user.
2. The classifier loads the last 30 analyzed games within 30 days (clocks, evals, best moves, opening labels included).
3. Per-move theme rules emit **zero or more** independent diagnoses (multi-label).
4. Game-scoped passes add `lost_winning_positions` and elevated-rate `time_pressure`.
5. Only occurrences with `confidence >= 0.65` are persisted; events aggregate by theme; cycles receive frequency, severity, and lifecycle status.
6. Rails displays the weakness report at `/weaknesses` with severity + confidence evidence links.

Each classification run is a **full recompute** for the user (non-archived cycles). Re-running with identical artifacts produces identical metrics.

## Package layout

All code lives under [`analysis/worker/weakness_package/`](../analysis/worker/weakness_package/).

| Module           | Role                                                                 |
| ---------------- | -------------------------------------------------------------------- |
| `handler.py`     | Orchestrates load → classify → aggregate → persist                   |
| `repository.py`  | Read window artifacts; write cycles/events; enqueue classify jobs    |
| `theme_rules.py` | Multi-label rules + evidence/confidence + new theme detectors        |
| `aggregator.py`  | Multi-label classify; game+theme dedupe; severity; episode passes    |
| `cycles.py`      | Activation thresholds and lifecycle status                           |
| `constants.py`   | Rails-aligned enums and tunable thresholds                           |
| `types.py`       | Dataclasses for artifacts, classified events, and cycle metrics      |

Job entry point: [`analysis/worker/classify_handlers.py`](../analysis/worker/classify_handlers.py).

## Theme classification (v1.1)

Eleven patterns (integers in `PATTERN`, matching `Patternable` in Rails):

| Theme                    | Primary signals                                                    |
| ------------------------ | ------------------------------------------------------------------ |
| Hanging pieces           | Material loss; threat with ignored hanging pieces                  |
| Missed tactics           | Tactical event + minimum CPL (~1.5 pawns)                          |
| Ignored threats          | Threat event + eval worsening                                      |
| Opening development      | King-safety signals in opening (e.g. delayed castling)             |
| King safety              | King-safety signals outside opening window                         |
| Bad trades               | Material loss on captures with eval worsening                      |
| Pawn structure           | Pawn-structure issues + eval worsening                             |
| Endgame technique        | Endgame phase + mistake CPL                                        |
| Time pressure            | Standalone when mistake rate under pressure exceeds baseline       |
| Moving too quickly       | Fast think time with adequate clock + mistake (non-opening)        |
| Lost winning positions   | Winning episode (`eval ≥ +200` × 2) collapses below equal floor    |

Phase 1.2’s eight MVP themes are covered; king safety, bad trades, and pawn structure are retained beyond that set.

### Multi-label + confidence

- One `pattern_occurrences` row per matching theme on a move (`primary_pattern` = that theme).
- `secondary_pattern` is no longer written for new classifications (column retained for old rows).
- Every occurrence has `confidence` (0–1) and structured `metadata.evidence` (played/best move, evals, CPL, clocks, detection reason).
- Persist threshold: `MIN_CONFIDENCE_TO_PERSIST = 0.65`.

Classifier policy: deterministic rules over engine events/evals only — no model-assisted labels.

## Recurring patterns and cycles

- **Detection window:** last 30 games played within 30 days (configurable in `constants.py`).
- **Deduping:** at most one weakness event per game per theme (highest-severity move kept).
- **Frequency:** `games_affected / games_analyzed` (0–100%, never above 100%).
- **Activation:** ≥ 3 games with the theme across ≥ 2 distinct games promotes a cycle from `detected` → `active`.
- **Severity:** weighted combination of occurrence (frequency), impact (event severity), and recency (exponential decay).
- **Lifecycle:** `detected` → `active` → `improving` (30% reduction) → `managed` (75% reduction) → `archived`.

## Rails consumption

- **Enqueue:** automatically after each `analyze_game` success (deduped per user).
- **UI:** [`PatternCyclesController`](../app/controllers/pattern_cycles_controller.rb) index (top weaknesses) and show (linked games/moves + confidence).

## Configuration

Thresholds live in [`analysis/worker/weakness_package/constants.py`](../analysis/worker/weakness_package/constants.py). Key tunables:

| Constant                       | Default | Purpose                              |
| ------------------------------ | ------- | ------------------------------------ |
| `DETECTION_WINDOW_GAMES`       | 30      | Max games in lookback                |
| `DETECTION_WINDOW_DAYS`        | 30      | Max age of games in lookback         |
| `MIN_OCCURRENCES_FOR_ACTIVE`   | 3       | Recurring-pattern activation         |
| `MIN_GAMES_FOR_ACTIVE`         | 2       | Spread across games required         |
| `IMPROVING_THRESHOLD`          | 0.30    | Frequency reduction for improving    |
| `MANAGED_THRESHOLD`            | 0.75    | Frequency reduction for managed      |
| `MIN_CONFIDENCE_TO_PERSIST`    | 0.65    | Minimum confidence to store/cycle    |

## Testing

| Layer                 | Location                                                                                      |
| --------------------- | --------------------------------------------------------------------------------------------- |
| Unit                  | `analysis/tests/test_weakness_theme_rules.py`, `test_weakness_aggregator.py`, `test_pattern_cycles.py` |
| Determinism           | `analysis/tests/test_weakness_determinism.py`                                                 |
| Python integration    | `analysis/tests/test_classify_handler_integration.py`                                         |
| Rails request specs   | `spec/requests/weaknesses_spec.rb`                                                            |
| Rails E2E slice       | `spec/integration/weakness_pipeline_spec.rb` (skipped without Stockfish + Python deps)        |

Run Python tests: `make test-python`. Full suite: `make test`.

## Determinism

Given identical candidate events and move evaluations in the detection window, the classifier produces identical cycle metrics (theme, status, occurrences, severity). No LLM involvement — rule-based only.
