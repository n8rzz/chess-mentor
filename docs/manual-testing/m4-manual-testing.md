---
title: M4 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - evaluation
  - stockfish
  - milestone-4
---

# M4 manual testing checklist

Use this checklist for **Milestone 4: Evaluation engine** — Stockfish analysis pipeline, games list/detail with move classifications.

Prerequisites: [m3-manual-testing.md](m3-manual-testing.md) (imported games).

Related docs:

- [evaluation-engine.md](../evaluation-engine.md)
- [make-commands.md](../development/make-commands.md)

**PRD checkpoint:** User can analyze imported games and view classifications.

---

## Prerequisites

```bash
docker compose up -d db redis
make stack-up                    # workers need Stockfish in Docker image
bin/rails db:seed
bin/dev
```

Sign in as **`starship@example.com`** / **`skyd!ve`**.

Demo analysis artifacts come from `05_demo_analysis.rb` (no Stockfish required for §2). Live analysis requires workers with Stockfish (`STOCKFISH_PATH` in `.env.worker`).

---

## 1. Automated suite (CI gate)

```bash
make test
```

M4-relevant specs:

- `spec/requests/games_spec.rb`
- `spec/services/analysis_runs/bulk_enqueue_for_import_spec.rb`
- `spec/services/analysis_runs/reconcile_all_spec.rb`
- `spec/integration/analysis_reconciliation_spec.rb`
- `spec/integration/analysis_pipeline_spec.rb` (pending without Stockfish)
- `analysis/tests/test_parser*.py`, `test_eval*.py`, `test_detectors*.py`

---

## 2. Games list (demo seed, offline)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | Open **Games** (`/games`) | Demo games listed (opponent, date, time class) |
| 2.2 | Check analysis status per game | Succeeded / pending / running indicators as seeded |
| 2.3 | If pending runs exist | Hint mentions workers (`bin/dev` / `docker compose up worker`) |

---

## 3. Game detail (demo seed, offline)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 3.1 | Open a game with succeeded analysis | Move list with SAN (e.g. `Nf3`) |
| 3.2 | User moves | Classification labels: good, inaccuracy, mistake, blunder |
| 3.3 | User moves | Centipawn loss values shown |
| 3.4 | Game still analyzing | Progress hint on detail page |

---

## 4. Live worker path — analyze imported game

Use a freshly imported game or trigger reconciliation.

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | Import games (M3) with worker running | `analyze_game` jobs enqueued after import succeeds |
| 4.2 | Wait for worker (~30s–2min per game) | `AnalysisRun` status **succeeded** |
| 4.3 | Refresh game detail | Move evaluations and classifications appear |
| 4.4 | Check DB | `moves`, `move_evaluations`, `candidate_events` rows for the game |

**If analysis stalls:** worker logs, Stockfish path, corrupt PGN errors in `analysis_runs.error_message`.

---

## 5. Analysis reconciliation

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | Import batch succeeds but analysis jobs were missed | Visiting import batch show triggers reconciliation (or Sidekiq `ReconcileJob`) |
| 5.2 | Pending `AnalysisRun` with no job | Re-enqueue without duplicate jobs |

---

## 6. Authorization

| Step | Action | Expected |
| ---- | ------ | -------- |
| 6.1 | Second user opens another user's game URL | **404** |
| 6.2 | Games list | Only current user's games |

---

## Minimum bar before merge

1. `make test` green (pipeline spec may skip without Stockfish)
2. Demo seed: games list + detail with classifications
3. Live: import → `analyze_game` succeeds → classifications on game show
4. Other user's game → 404

---

## Automated test coverage map

| Scenario | Automated coverage | Spec / notes |
| -------- | ------------------- | ------------ |
| Games list + detail HTML | Yes | `spec/requests/games_spec.rb` |
| Analysis pending hints | Yes | Request spec |
| Bulk enqueue + reconcile | Yes | Service + integration specs |
| Parser, CPL, detectors | Yes | Python unit tests |
| Stockfish integration | Partial | Skipped in CI without binary |
| Full import → analyze E2E in browser | **No** | `analysis_pipeline_spec` subprocesses Python |
| Visual move list layout | **No** | Manual only |

---

## Out of scope (M4)

- Weakness classification (M5)
- Interactive board / move stepping (M8)
- Re-analysis when engine version changes (immutable runs by design)
