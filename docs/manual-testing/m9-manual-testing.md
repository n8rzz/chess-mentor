---
title: M9 — End-to-end workflow manual testing
last_modified: 2026-06-18
tags:
  - development
  - testing
  - manual-testing
  - m9
---

# M9 — End-to-end workflow manual testing

Full MVP walkthrough for staging or local demo with live services. Automated coverage: [test-plan.md](../testing/test-plan.md).

**Prerequisites:** `docker compose up` (Postgres, Redis, worker), `bin/dev` or Rails + Sidekiq, seeded puzzles (`bin/rails db:seed`), Lichess OAuth app configured.

## 1. Register and connect

| Step | Action | Expected |
| ---- | ------ | -------- |
| 1.1 | Sign up with email/password | Land on `/dashboard` |
| 1.2 | Connect Lichess (live OAuth) | Dashboard shows linked account |
| 1.3 | Disconnect/reconnect (optional) | No duplicate accounts |

## 2. Import games

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | Start import (7 days, blitz, max 10) | Redirect to import status page |
| 2.2 | Wait for worker | Status → `succeeded` or `partially_succeeded` |
| 2.3 | Partial batch (if applicable) | Failed games listed with error messages |

## 3. Analyze and classify

| Step | Action | Expected |
| ---- | ------ | -------- |
| 3.1 | Open import batch after success | Analysis jobs enqueued (check games list) |
| 3.2 | Wait for analysis | Games show `succeeded` analysis status |
| 3.3 | Open `/weaknesses` | At least one recurring weakness cycle |

## 4. Training plan

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | Open `/training_plans` | Recommended plans from weakness cycles |
| 4.2 | Start a plan | Plan page; assignments generate within ~1 min |
| 4.3 | Open today's assignments | Puzzle / review / habit tasks listed |

## 5. Complete exercise and track progress

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | Complete or solve one assignment | Status updates; redirect to today view |
| 5.2 | Open dashboard | Progress charts and active plan summary |
| 5.3 | Over multiple sessions | Weakness frequency trend decreases (criterion #8) |

## 6. Failure visibility

| Step | Action | Expected |
| ---- | ------ | -------- |
| 6.1 | Import with revoked token | Batch `failed` with error message |
| 6.2 | Analysis failure (if reproducible) | Game shows `failed` analysis + error on detail page |
| 6.3 | Stuck import (kill worker mid-run) | After ~30 min, reconcile re-enqueues (or manual retry) |

## Automated equivalents

```bash
make test
bundle exec rspec spec/integration/full_workflow_pipeline_spec.rb spec/system/mvp_workflow_spec.rb
```
