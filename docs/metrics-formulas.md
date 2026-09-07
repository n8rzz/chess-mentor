---
title: Performance Metric Formulas
last_modified: 2026-09-07
prd: docs/prd-phase1.2.md
description: Versioned formulas for game_metrics and review_period_metrics.
tags:
  - metrics
  - analysis
  - versioning
---

# Performance Metric Formulas

**Formula version:** `1.0.0` (`AnalysisVersions::METRIC_FORMULA_VERSION`)

Scope: user moves (`played_by_user`) on a succeeded `analysis_run`. Rates are `null` when the denominator is 0. Moves missing clocks are skipped for time/fast-move metrics.

## Per-game (`game_metrics`)

| Metric | Formula |
| --- | --- |
| ACPL | `AVG(centipawn_loss)` over user move evaluations |
| Inaccuracies / mistakes / blunders | counts by classification (`inaccuracy` / ≥ `mistake` / `blunder`) |
| Phase performance | ACPL + mistake/blunder counts keyed by `moves.phase` (`opening`, `middlegame`, `endgame`) |
| Conversion | Winning state = `eval_before_cp ≥ +200` for 2 consecutive user moves. Episode ends lost if eval drops `< +75`. Converted if episode held and `games.result = win`. Store `winning_positions_reached` / `_converted`. |
| Time-pressure error rate | `(mistakes + blunders)` on time-pressure moves / time-pressure user moves. Time pressure = `analysis_events.event_type = time_pressure` **or** `clock_before ≤` class threshold (bullet 5 / blitz 15 / rapid 60 / classical 180 / unknown 60). |
| Fast-move error rate | Think time ≈ `clock_before − clock_after + increment` (increment from `games.time_control`). Fast if think time ≤ 2s (bullet/blitz) or ≤ 3s (rapid/classical/unknown), `clock_before ≥ 30`, and `phase ≠ opening`. Error if classification ≥ mistake. Rate = fast errors / fast moves. |
| Critical position accuracy | Among `critical_position` evaluations, share with classification `good` |

## Per-review-period (`review_period_metrics`)

Only member games with a `game_metrics` row at this formula version.

| Metric | Formula |
| --- | --- |
| Win / draw / loss rates | Counts over member games with known result (`unknown` excluded from denominator) |
| ACPL | Move-weighted mean: `sum(acpl × user_move_count) / sum(user_move_count)` |
| Mistakes / blunders per game | `sum(counts) / analyzed_games_count` |
| Phase / conversion / time / fast / critical | Pooled from game rows (same denominators as per-game, summed) |

## Thresholds (v1.0.0)

| Constant | Value |
| --- | --- |
| Winning CP | +200 |
| Winning consecutive user moves | 2 |
| Conversion equal floor | +75 |
| Fast remaining clock min | 30s |
| Fast think time (bullet/blitz) | ≤ 2s |
| Fast think time (rapid/classical/unknown) | ≤ 3s |
| Mistake classification | ≥ 100 CPL (`classification ≥ mistake`) |
