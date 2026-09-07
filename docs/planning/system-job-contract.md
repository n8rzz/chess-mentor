---
title: SystemJob — Database Contract
last_modified: 2026-06-04
tags:
  - system-job
  - worker
  - contract
  - planning
---

# SystemJob — Database Contract

Rails and the Python analysis worker coordinate through the `system_jobs` table only. Rails must not depend on Python modules or in-process APIs—only rows, status fields, and JSON columns ([domain-models §24](domain-models.md)).

**MVP transport:** Postgres polling. Optional Redis wake-up is post–Phase 1 ([PRD §15](prd.md), [todo.md](../todo.md)).

## Table

`system_jobs` — see migration `create_system_jobs`.

## Status enum

| Integer | String       | Set by   |
| ------- | ------------ | -------- |
| 0       | `pending`    | Rails    |
| 1       | `claimed`    | Worker   |
| 2       | `processing` | Worker   |
| 3       | `succeeded`  | Worker   |
| 4       | `failed`     | Worker   |
| 5       | `cancelled`  | Rails    |

### Allowed transitions

```text
pending → claimed → processing → succeeded
                              → failed
pending → cancelled (Rails only)
failed → pending (Rails retry via SystemJobs::Retry when retryable?)
```

Terminal rows (`succeeded`, `failed`, `cancelled`) must not be updated by Rails validations except `failed → pending` for retry (`SystemJobs::Retry` when `retryable?`). Workers should not rewrite terminal jobs.

## Retry and reconciliation (M9)

Rails reconcilers (invoked from `AnalysisRuns::ReconcileJob` every ~30s):

| Service | Purpose |
| ------- | ------- |
| `ImportBatches::ReconcileStuck` | Retry failed `import_games` jobs; enqueue imports for stuck `pending`/`running` batches without an active job |
| `SystemJobs::ReconcileStuckProcessing` | Fail orphaned `claimed`/`processing` jobs whose lease (`updated_at`) exceeded the type timeout; retry when attempts remain; fail pending/running `AnalysisRun` when analyze retries are exhausted |
| `AnalysisRuns::ReconcileAll` | Enqueue analysis for terminal imports and stuck pending `AnalysisRun` rows |
| `SystemJobs::ReconcileFailed` | Retry failed `classify_patterns` / `generate_training_plan` when parent entity still pending |

Lease timeouts (override with `SYSTEM_JOB_STUCK_TIMEOUT_<JOB_TYPE>_SECONDS`):

| job_type | Default |
| -------- | ------- |
| `import_games` | 20 minutes |
| `analyze_game` | 30 minutes |
| `classify_patterns` / `generate_training_plan` / `update_progress_snapshots` / `refresh_review_period_metrics` | 15 minutes |

Python workers heartbeat in-progress jobs every `SYSTEM_JOB_HEARTBEAT_SECONDS` (default 30) by bumping `updated_at`, so live long Stockfish runs are not marked stuck.

`SystemJobs::Retry` resets a failed job to `pending`, clears errors, keeps `attempts_count`. Retry is allowed while `attempts_count < MAX_ATTEMPTS` (3).

Import handler idempotency: re-running `import_games` on a terminal `ImportBatch` returns existing counts without side effects.

## Job type enum

| Integer | String                          |
| ------- | ------------------------------- |
| 0       | `import_games`                  |
| 1       | `analyze_game`                  |
| 2       | `classify_patterns`             |
| 3       | `generate_training_plan`        |
| 4       | `update_progress_snapshots`     |
| 5       | `refresh_review_period_metrics` |

Python reads/writes **string** keys in SQL filters where noted below; Rails uses integer-backed enums with these keys.

## Payload (input)

JSON object, string keys. Required keys per type when parent tables exist:

| job_type                    | Required keys                                 |
| --------------------------- | --------------------------------------------- |
| `import_games`              | `import_batch_id`                             |
| `analyze_game`              | `analysis_run_id`, `game_id`                  |
| `classify_patterns`       | optional `user_id` if not inferred from row   |
| `generate_training_plan`    | `training_plan_id`                            |
| `update_progress_snapshots` | optional `user_id` if not inferred from row   |
| `refresh_review_period_metrics` | optional `user_id` if not inferred from row |

MVP stubs may accept extra keys (e.g. `dry_run`) for smoke tests.

## Result (output)

Small JSON summary for UI/debug only. Heavy artifacts live on domain tables (`ImportBatch`, `AnalysisRun`, etc.).

Stub success example:

```json
{ "stub": true, "job_type": "import_games" }
```

## Errors

- `error_message` — human-readable string
- `error_details` — optional JSON, e.g. `{ "code": "handler_error", "context": {} }`

## Worker claim flow

1. `SELECT id FROM system_jobs WHERE status = 0 ORDER BY created_at ASC LIMIT 1 FOR UPDATE SKIP LOCKED`
2. `UPDATE` → `claimed`, set `claimed_by`, increment `attempts_count`, set `started_at`
3. `UPDATE` → `processing`
4. Run handler by `job_type`
5. `UPDATE` → `succeeded` with `result` **or** `failed` with `error_message` / `error_details`; set `finished_at`

## Enqueue (Rails)

```ruby
SystemJobs::Create.call(user: user, job_type: :import_games, payload: { "import_batch_id" => batch.id })
```

Creates `pending`, `attempts_count: 0`, `payload` with string keys.

## Post-import analysis enqueue (M3)

Rails owns `AnalysisRun` + `analyze_game` job creation ([domain-models §20](domain-models.md)). Python only imports games.

When the import status page loads a terminal batch (`succeeded` or `partially_succeeded`) and `ImportBatch.metadata["analysis_enqueued_at"]` is absent, Rails runs `AnalysisRuns::BulkEnqueueForImport` once (idempotent). This inserts pending `AnalysisRun` rows and enqueues `analyze_game` jobs. Handlers remain stubs until Milestone 4.

## Manual smoke

```bash
# Terminal 1
docker compose up worker

# Terminal 2
bin/rails runner 'SystemJobs::Create.call(user: User.first, job_type: :import_games, payload: { "dry_run" => true })'
```

Expect status → `succeeded` with stub `result` within a few poll intervals.
