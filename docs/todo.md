---
title: Phase 1.2 — Task List
last_modified: 2026-09-06
prd: docs/prd-phase1.2.md
description: High-level Phase 1.2 checklist derived from the PRD. Read the PRD for full requirements and acceptance criteria.
tags:
  - tasks
  - checklist
  - planning
---

## Phase 1.2 Tasks - PRD

### Domain, versioning & platform concerns

- [x] Align domain model with Game → Position → Analysis Event → Theme Occurrence → Review Period → Training Goal
- [x] Version analysis settings, metric formulas, and theme classifiers
- [x] Respect Lichess rate limits and incremental sync
- [x] Treat analysis/training data as private user data

### Stockfish analysis

- [ ] Evaluate player moves (eval before/after, best vs played, CPL, PV, mates)
- [ ] Two-pass analysis: shallow scan, then deeper MultiPV on critical positions
- [ ] Persist engine results and avoid identical reanalysis; run analysis asynchronously

### Critical positions & game phases

- [ ] Detect critical positions beyond CPL alone (eval swings, forced lines, time pressure, candidate dispersion)
- [ ] Classify positions as opening / middlegame / endgame

### Performance metrics

- [ ] Define and version core metrics (win/draw/loss, ACPL, mistakes/blunders, phase performance, conversion, time/fast-move error rates)
- [ ] Aggregate metrics per game and per review period

### Theme system

- [ ] Ship MVP theme taxonomy (hanging pieces, missed tactics/threats, poor opening, time trouble, moving too quickly, lost winning positions, endgame mistakes)
- [ ] Prefer deterministic rules, then engine-based classification; treat model-assisted labels as lower confidence
- [ ] Attach confidence scores and link every diagnosis to supporting positions (evidence)

### Strengths, trends & normalization

- [ ] Identify recurring strengths as well as weaknesses
- [ ] Compare themes across review periods with sample-size awareness
- [ ] Normalize metrics for fair cross-period comparison (avoid raw counts)

### Review report & dashboard

- [ ] Generate review reports: performance summary, strongest areas, primary weaknesses, trends, recommended focus
- [ ] Dashboard: current performance, strengths/weaknesses, trends, active training, recent analysis
- [ ] Theme detail view with occurrences, evidence positions, and drill-down into games

### Opening analysis

- [ ] Track opening performance by ECO/opening family (no full repertoire builder)

### Training loop

- [ ] Create training goals from weak themes with recommended activities
- [ ] Track training completion
- [ ] Measure training effectiveness against future real-game performance (close the diagnosis → train → reassess loop)

## Phase 1.2 — Charts

- [ ] Graph by game phase
  - show CPL by game phase [`opening`, `middlegame`, `endgame`]
- [ ] Graph training program timeline and progress over time
