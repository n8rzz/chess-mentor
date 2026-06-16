---
title: M7 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - dashboard
  - progress
  - milestone-7
---

# M7 manual testing checklist

Use this checklist for final confirmation before merging **Milestone 7: Dashboard & progress tracking**. It complements automated tests (`make test`) with checks that are hard to cover in CI: Chart.js rendering, async `update_progress_snapshots` jobs, and full dashboard composition with live worker data.

Related docs:

- [m6-manual-testing.md](m6-manual-testing.md) — training plan and assignment flows (prerequisite for several M7 checks)
- [README.md](README.md) — index of all milestone checklists
- [make-commands.md](../development/make-commands.md) — `make test`, `make stack-up`, worker scaling
- [README.md](README.md) — index of all milestone checklists
- [prd.md](../planning/prd.md) §13 — dashboard summary and chart requirements

**PRD checkpoint:** User can track progress over time.

---

## Prerequisites

```bash
cp .env.example .env          # if not done already
cp .env.worker.example .env.worker
docker compose up -d db redis
make stack-up                   # or: make workers-up + bin/dev in another terminal
bin/rails db:seed               # development only
bin/dev                         # Rails + Tailwind + Sidekiq
```

Sign in as **`starship@example.com`** / **`skyd!ve`** (from `db/seeds/01_users.rb`).

Demo data used below comes from seeds `03`–`08` (games, analysis, weaknesses, training plan, progress snapshots).

**Verify after seed** (starship should have an active in-progress plan):

| Check | How |
| ----- | --- |
| Demo plan exists | `db:seed` output includes _“Seeded demo training plan … 112 assignments, 8 due today”_ |
| Dashboard | **Training plan** card shows **Missed tactics** · **active** and **Today's tasks: 0/8 completed** (not “No active plan” or `0/0`) |
| Charts | **Progress charts** section shows canvases (depends on `08_demo_progress.rb` and the demo plan from `07`) |

`07_demo_training.rb` reactivates the demo plan when it was archived/completed, the plan window expired, or no assignments are due today (common after M6 manual testing). Re-run `bin/rails db:seed` to refresh.

**Section 5 (empty user):** use a **newly registered user**, not starship — the demo account intentionally has an active plan.

---

## 1. Automated suite (CI gate)

```bash
make test
```

**Pass:** 0 failures. Two pending Stockfish integration specs are expected if Stockfish is not installed on the host.

M7-specific specs (also run by `make test`):

- `spec/requests/dashboard_spec.rb`
- `spec/system/dashboard_spec.rb`
- `spec/services/dashboard/`
- `spec/services/progress_snapshots/enqueue_spec.rb`
- `spec/db/seeds/demo_progress_spec.rb`
- `analysis/tests/test_progress_calculators.py`
- `analysis/tests/test_progress_handler_integration.py`

---

## 2. Dashboard summary (demo seed, offline)

Confirms summary cards render from existing DB data **without waiting on workers**.

| Step | Action               | Expected                                                                                                             |
| ---- | -------------------- | -------------------------------------------------------------------------------------------------------------------- |
| 2.1  | Open `/dashboard`    | **Summary** section at top with **Current ratings** chips (bullet / blitz / rapid / classical) and **Analysis** line |
| 2.2  | Check ratings        | Blitz (and others with demo games) show numeric ratings; missing time classes show **—**                             |
| 2.3  | Check analysis       | Shows analyzed count and imported game count; **View games** links to `/games`                                       |
| 2.4  | Providers card       | Lichess connected (if seeded) or connect prompt — unchanged from M6                                                  |
| 2.5  | Recent imports       | Latest batch status and count — unchanged from M6                                                                    |
| 2.6  | Recurring weaknesses | Top weaknesses with links — unchanged from M6                                                                        |

---

## 3. Training progress panel (demo seed)

Builds on M6 demo plan (`07_demo_training.rb`). Confirms the enhanced training card and live progress sync.

| Step | Action                                       | Expected                                                                                 |
| ---- | -------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 3.1  | On `/dashboard`, find **Training plan** card | **Objective** (theme label), status, **Today's tasks** (`X/Y completed`), days remaining |
| 3.2  | Check progress bar                           | Bar shows current %; markers at **30%** (improving) and **75%** (managed)                |
| 3.3  | Click **View plan**                          | Progress % on plan show matches dashboard (both run `TrainingPlans::SyncProgress`)       |
| 3.4  | Click **Today's assignments**                | Today view loads; complete one assignment                                                |
| 3.5  | Return to `/dashboard`                       | **Today's tasks** completed count increased                                              |

**If you see “No active plan” or `Today's tasks: 0/0` on starship:** the demo plan is missing or stale. Re-run `bin/rails db:seed` (see **Verify after seed** above). If seed output does not mention the demo training plan, confirm `06_demo_weaknesses.rb` ran (active **missed_tactics** cycle required).

## 4. Progress charts (demo seed)

Confirms Chart.js + Stimulus rendering from `08_demo_progress.rb` (8 weekly snapshot batches).

| Step | Action                                        | Expected                                                  |
| ---- | --------------------------------------------- | --------------------------------------------------------- |
| 4.1  | Scroll to **Progress charts** on `/dashboard` | Up to four chart cards (not the empty-state placeholder)  |
| 4.2  | Rating history                                | Line chart with blitz rating trend                        |
| 4.3  | Weakness trend                                | Line chart for active plan's weakness cycle (occurrences) |
| 4.4  | Blunders per game                             | Line chart with downward trend (demo data)                |
| 4.5  | Average centipawn loss                        | Line chart present                                        |
| 4.6  | Browser console                               | No JavaScript errors on dashboard load                    |

**If charts are missing:** confirm `08_demo_progress.rb` ran (`ProgressSnapshot.where("metadata->>'seed_key' = ?", "demo_progress_snapshots").count` → 32).

---

## 5. Empty / minimal user states

| Step | Action                                      | Expected                                                                             |
| ---- | ------------------------------------------- | ------------------------------------------------------------------------------------ |
| 5.1  | Sign up as a **new** user (not starship)    | Dashboard loads without error                                                        |
| 5.2  | Summary ratings                             | All time classes show **—**                                                          |
| 5.3  | Analysis                                    | **0 analyzed**; game count 0                                                         |
| 5.4  | Training plan card                          | **No active plan** + **Browse recommendations**                                      |
| 5.5  | Progress charts                             | Placeholder: _“Trend charts appear after multiple progress snapshots are recorded.”_ |

---

## 6. Live worker path — progress snapshots

Confirms `update_progress_snapshots` runs after classification and writes rows the dashboard charts consume.

| Step | Action                                                                                     | Expected                                                                                              |
| ---- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| 6.1  | Ensure worker is running (`docker compose ps`)                                             | Worker container healthy                                                                              |
| 6.2  | Use a user with analyzed games but few/no snapshots (or archive demo plan and re-import)   | Classification pipeline can run                                                                       |
| 6.3  | Trigger `classify_weaknesses` (happens automatically after each successful `analyze_game`) | `system_jobs` row with `job_type` **classify_weaknesses** succeeds                                    |
| 6.4  | Check `system_jobs` after classification                                                   | Pending or succeeded **`update_progress_snapshots`** job for the user (deduped — at most one pending) |
| 6.5  | Wait for worker; confirm `progress_snapshots` rows                                         | Rows with `metadata->>'kind'` of `rating`, `performance`, `weakness`, and/or `training`               |
| 6.6  | Run classification + snapshot **twice** (e.g. two import/analyze cycles)                   | Dashboard charts appear once a series has ≥2 points                                                   |

**If snapshots never appear:** check worker logs (`docker compose logs worker`), Redis, and that `classify_weaknesses` completed successfully.

---

## 7. Assignment complete → snapshot enqueue

| Step | Action                                          | Expected                                                                                   |
| ---- | ----------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 7.1  | On an active plan, open **Today's assignments** | 8 items for today                                                                          |
| 7.2  | Click **Complete** on one assignment            | Redirect to today view; status **completed**                                               |
| 7.3  | Check `system_jobs`                             | New **`update_progress_snapshots`** job enqueued (skipped if one is already pending)       |
| 7.4  | After worker processes job, refresh dashboard   | Training-related snapshot metadata updated (may affect charts after enough history exists) |

---

## 8. Authorization and scoping

| Step | Action                       | Expected                                                                  |
| ---- | ---------------------------- | ------------------------------------------------------------------------- |
| 8.1  | Sign in as a **second** user | Dashboard shows that user's own summary/plan/charts — not starship's data |
| 8.2  | Sign out                     | Redirect to home; `/dashboard` requires sign-in                           |

---

## 9. Docker worker stack (infra regression)

Same as M6 — verifies migrate + workers start cleanly.

```bash
docker compose down
docker compose up --build --scale worker=4 -d
```

**Pass:**

- `migrate` service exits successfully
- Worker containers stay running (no crash loop)
- Worker logs show jobs being claimed and processed (including `update_progress_snapshots`)

---

## Minimum bar before merge

If time is tight, these six checks are enough:

1. `make test` green
2. Demo user: dashboard **Summary** shows ratings + analysis counts
3. Demo user: **Training plan** panel with progress bar and today's tasks
4. Demo user: **Progress charts** render (four canvases, no console errors)
5. Empty user: correct placeholders (no plan, no charts)
6. Worker path: `classify_weaknesses` → `update_progress_snapshots` → `progress_snapshots` rows created

---

## Automated test coverage map

| Scenario                                  | Automated coverage | Spec / notes                                                  |
| ----------------------------------------- | ------------------ | ------------------------------------------------------------- |
| `make test`                               | Yes                | `Makefile` targets                                            |
| Dashboard summary ratings + analysis      | Yes                | `spec/services/dashboard/summary_spec.rb`, request spec       |
| Dashboard training panel                  | Yes                | Request spec (with synced weakness cycle data)                |
| Progress chart HTML + canvas              | Partial            | Request spec (data attributes); system spec (canvas present)  |
| Chart.js rendering / visual correctness   | **No**             | Manual only                                                   |
| Empty dashboard states                    | Partial            | Request spec (no plan); not all empty states                  |
| `update_progress_snapshots` worker        | Yes                | Python unit + integration tests                               |
| Enqueue after classify                    | Partial            | Python classify handler enqueues; no full E2E through analyze |
| Enqueue after assignment complete         | Yes                | `ProgressSnapshots::Enqueue` service spec                     |
| Snapshot → chart data series              | Yes                | `spec/services/dashboard/progress_data_spec.rb`               |
| Demo progress seed idempotent             | Yes                | `spec/db/seeds/demo_progress_spec.rb`                         |
| Worker stack migrate + multi-worker       | **No**             | Manual only                                                   |
| Progress % sync on dashboard vs plan show | **No**             | Both call `SyncProgress`; no dedicated spec                   |

---

## Out of scope (do not block M7 merge)

- Chess board / puzzle solve UI (M8)
- Scheduled/cron snapshot jobs (event-driven enqueue only in M7)
- Chart interactivity beyond basic tooltips
- Re-analysis of historical games when engine version changes (immutable analysis by design)
- Multiple simultaneous active plans
