---
title: M6 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - training
  - milestone-6
---

# M6 manual testing checklist

Use this checklist for final confirmation before merging **Milestone 6: Training plans & puzzles**. It complements automated tests (`make test`) with checks that are hard to cover in CI: Docker worker wiring, async job completion, and full HTML composition on the today view.

Related docs:

- [training-plan-engine.md](../training-plan-engine.md) — generator rules and assignment counts
- [make-commands.md](../development/make-commands.md) — `make test`, `make stack-up`, worker scaling
- [README.md](README.md) — index of all milestone checklists
- [m5-manual-testing.md](m5-manual-testing.md) — weakness classifier (prerequisite)
- [m7-manual-testing.md](m7-manual-testing.md) — dashboard and progress tracking (next milestone)

**PRD checkpoint:** User can select a plan and complete exercises (text-based UI; interactive board is M8).

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

---

## 1. Automated suite (CI gate)

```bash
make test
```

**Pass:** 0 failures. Two pending Stockfish integration specs are expected if Stockfish is not installed on the host.

---

## 2. Demo seed smoke test (offline UI)

Confirms seeds, dashboard, and plan UI **without waiting on workers**. The demo plan is created by `db/seeds/07_demo_training.rb` with 112 pre-seeded assignments.

| Step | Action                                       | Expected                                                                                                                         |
| ---- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 2.1  | Open `/dashboard`                            | **Training plan** card shows **Missed tactics**, progress %, links to plan and today                                             |
| 2.2  | Open **Training** in nav → `/training_plans` | **Current plan** section (not “Start plan” recommendations)                                                                      |
| 2.3  | Click **View plan**                          | Progress stats, **Today's assignments** button, 14 days of assignments grouped by date (no amber “still being generated” banner) |
| 2.4  | Click **Today's assignments**                | **8 items** for today: 1 personal review, 5 theme puzzles (rating/difficulty lines), 1 play game, 1 habit exercise               |
| 2.5  | Click **Complete** on one assignment         | Redirects to today view; status **completed**; Complete/Skip buttons gone for that row                                           |
| 2.6  | Click **Skip** on another                    | Status **skipped**; buttons gone for that row                                                                                    |

**Note:** Puzzles are text-only (rating, difficulty). No chess board — that is M8.

---

## 3. Live worker path (end-to-end job)

Confirms the `generate_training_plan` system job runs through Sidekiq and Python workers. Use a **fresh** plan, not the demo seed.

| Step | Action                                              | Expected                                                                                                        |
| ---- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 3.1  | On the demo plan, click **Archive** or **Complete** | Redirect to `/training_plans`; no current plan                                                                  |
| 3.2  | Open `/training_plans`                              | Up to **3 recommendations** with **Start plan** buttons (requires demo weaknesses from `06_demo_weaknesses.rb`) |
| 3.3  | Click **Start plan** on a recommendation            | Redirect to plan show; amber banner: _“Assignments are still being generated. Refresh this page in a moment.”_  |
| 3.4  | Wait ~10–30 seconds; refresh plan show              | Banner gone; **112 assignments** across 14 days (8 per day)                                                     |
| 3.5  | Open **Today's assignments**                        | 8 pending assignments for today                                                                                 |
| 3.6  | Complete and skip one assignment each               | Same behavior as steps 2.5–2.6                                                                                  |

**If assignments never appear:** check workers (`docker compose ps`), worker logs (`docker compose logs worker`), Redis, and that the one-shot migrate service succeeded (`docker compose logs migrate`).

---

## 4. Plan lifecycle

Run on an **active** plan (demo or worker-generated).

| Step | Action                                                  | Expected                                            |
| ---- | ------------------------------------------------------- | --------------------------------------------------- |
| 4.1  | Click **Pause**                                         | Status **paused**; dashboard still shows the plan   |
| 4.2  | Click **Resume**                                        | Status **active** again                             |
| 4.3  | Click **Complete**                                      | Status **completed**; redirect to `/training_plans` |
| 4.4  | Start another plan (or re-seed), then click **Archive** | Status **archived**; redirect to index              |

**Error path:** pause an already-paused plan → alert on plan show (_“Only active plans can be paused”_).

---

## 5. Plan extension (optional)

Extension only appears when `ends_at` is in the past and the plan is not **managed**. The demo plan’s `ends_at` is 14 days out, so you need a date tweak.

In Rails console:

```ruby
plan = TrainingPlan.current_for.find_by(user: User.find_by!(email: "starship@example.com"))
plan.update!(ends_at: 1.day.ago, progress_percentage: 10.0, status: :active)
```

| Step | Action                     | Expected                                                                                                           |
| ---- | -------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 5.1  | Reload plan show           | **Extend 14 days** button visible                                                                                  |
| 5.2  | Click **Extend 14 days**   | Success notice; `ends_at` pushed forward; new `generate_training_plan` job enqueued (`extension: true` in payload) |
| 5.3  | Wait and refresh plan show | **224** total assignments (days 0–27); today still has 8 items                                                     |

Skip this section if time is short — extension logic is covered by automated service and Python tests.

---

## 6. Authorization and scoping

| Step | Action                                                           | Expected                                                                        |
| ---- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 6.1  | Sign in as a **second** user (create via sign-up or console)     | `/training_plans` shows recommendations or empty state, **not** starship’s plan |
| 6.2  | Paste another user’s plan URL while signed in as the second user | **404**                                                                         |

---

## 7. Docker worker stack (infra regression)

Verifies the M6 fix where workers started before migrations caused `relation "system_jobs" does not exist`.

```bash
docker compose down
docker compose up --build --scale worker=4 -d
```

**Pass:**

- `migrate` service exits successfully
- Worker containers stay running (no crash loop)
- Worker logs show jobs being claimed and processed

---

## Minimum bar before merge

If time is tight, these five checks are enough:

1. `make test` green
2. Demo seed: dashboard → plan show → today (8 assignments)
3. Complete + skip on today view
4. Start plan → worker generates assignments → refresh shows 112
5. Pause → resume → complete (or archive)

---

## Automated test coverage map

Most scenarios above have partial or full automated coverage. Manual testing still matters for gaps CI cannot easily hit.

| Scenario                               | Automated coverage | Spec / notes                                                                                |
| -------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| `make test`                            | Yes                | `Makefile` targets                                                                          |
| Dashboard active / empty plan          | Yes                | `spec/requests/dashboard_spec.rb`                                                           |
| Index: current plan vs recommendations | Yes                | `spec/requests/training_plans_spec.rb`                                                      |
| Top 3 recommendations                  | Partial            | `spec/services/training_plans/recommend_spec.rb` (logic); index request uses one cycle      |
| Start plan + enqueue job               | Yes                | Request + `activate_spec.rb`                                                                |
| POST error paths                       | Yes                | Request specs                                                                               |
| Generation-pending banner              | Yes                | Request spec                                                                                |
| Plan show: 14 days × 8 assignments     | Partial            | `spec/db/seeds/demo_training_spec.rb` (112 rows); plan show request uses 1 assignment       |
| Today: 8 items, all types              | **No**             | Today request spec uses 1 assignment; Python generator tests assert daily counts            |
| Puzzle rating/difficulty in HTML       | **No**             | —                                                                                           |
| Complete / skip assignment             | Yes                | `spec/requests/training_assignments_spec.rb`                                                |
| Buttons hidden after complete          | **No**             | —                                                                                           |
| Worker generates 112 via job queue     | Partial            | `spec/integration/training_plan_pipeline_spec.rb` calls Python directly; skips without deps |
| Banner clears after generation         | **No**             | —                                                                                           |
| Pause / resume / complete / archive    | Yes                | Request + service specs                                                                     |
| Pause error path                       | Yes                | Request spec                                                                                |
| Extend eligible / ineligible           | Yes                | Request + `extend_spec.rb` + Python extension tests                                         |
| Extend → 224 in Rails UI               | **No**             | Python only                                                                                 |
| Extend button in HTML                  | **No**             | Model `eligible_for_extension?` tested                                                      |
| Other user 404                         | Yes                | Request specs                                                                               |
| Demo seed idempotent                   | Yes                | `spec/db/seeds/demo_training_spec.rb`                                                       |
| Docker migrate + workers               | **No**             | Manual only                                                                                 |
| 8/day counts, determinism, idempotency | Yes                | `analysis/tests/test_training_*.py`                                                         |

---

## Out of scope (do not block M6 merge)

- Chess board / puzzle solve UI (M8)
- Auto-detect play-game completion
- Multiple concurrent active plans
