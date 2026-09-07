---
title: Test plan — Phase 1 MVP
last_modified: 2026-06-18
tags:
  - testing
  - mvp
  - planning
---

# Test plan — Phase 1 MVP

This document maps MVP success criteria and workflow steps to automated and manual verification. Complements per-milestone checklists in [manual-testing/README.md](../manual-testing/README.md).

## MVP success criteria (PRD §17)

| # | Criterion | Automated | Manual |
| - | --------- | --------- | ------ |
| 1 | Connect a provider | `spec/requests/users/omniauth_callbacks_spec.rb`, `spec/system/dashboard_spec.rb` | [m1-manual-testing.md](../manual-testing/m1-manual-testing.md) |
| 2 | Import games | `spec/requests/import_batches_spec.rb`, `analysis/tests/test_import_handler_integration.py` | [m3-manual-testing.md](../manual-testing/m3-manual-testing.md) |
| 3 | Analyze games | `spec/integration/analysis_pipeline_spec.rb`, `analysis/tests/test_analyze_idempotency.py` | [m4-manual-testing.md](../manual-testing/m4-manual-testing.md) |
| 4 | View recurring weaknesses | `spec/requests/weaknesses_spec.rb`, `spec/integration/weakness_pipeline_spec.rb` | [m5-manual-testing.md](../manual-testing/m5-manual-testing.md) |
| 5 | Select a training plan | `spec/requests/training_plans_spec.rb`, `spec/integration/training_plan_pipeline_spec.rb` | [m6-manual-testing.md](../manual-testing/m6-manual-testing.md) |
| 6 | Complete exercises | `spec/requests/training_assignments_spec.rb`, `spec/system/mvp_workflow_spec.rb` | [m6-manual-testing.md](../manual-testing/m6-manual-testing.md) |
| 7 | Track progress | `spec/requests/dashboard_spec.rb`, `spec/db/seeds/demo_progress_spec.rb` | [m7-manual-testing.md](../manual-testing/m7-manual-testing.md) |
| 8 | Measurable weakness reduction | `spec/integration/weakness_improvement_spec.rb`, `spec/db/seeds/demo_progress_spec.rb` | [m9-manual-testing.md](../manual-testing/m9-manual-testing.md) |

## Workflow coverage matrix

| Step | Unit (Rails) | Request | Integration | System | Python |
| ---- | ------------ | ------- | ----------- | ------ | ------ |
| Import | `import_batch`, `import_record` models | `import_batches_spec` | `full_workflow_pipeline_spec` | `mvp_workflow_spec` | `test_import_handler_integration` |
| Analyze | `analysis_run` model | `games_spec` | `analysis_pipeline_spec`, `analysis_reconciliation_spec` | `mvp_workflow_spec` | `test_analyze_idempotency`, `test_engine_integration` |
| Classify | `pattern_cycle` model | `weaknesses_spec` | `weakness_pipeline_spec`, `full_workflow_pipeline_spec` | `mvp_workflow_spec` | `test_classify_handler_integration` |
| Training plan | `training_plan` services | `training_plans_spec` | `training_plan_pipeline_spec`, `full_workflow_pipeline_spec` | `mvp_workflow_spec` | `test_training_handler_integration` |
| Progress | `progress_snapshot` model | `dashboard_spec` | `domain_model_checkpoint_spec`, `weakness_improvement_spec` | `dashboard_spec` (charts) | `test_progress_handler_integration` |
| Job transport | `system_job` model | — | `system_job_worker_contract_spec` | — | worker `jobs.py` contract |

## End-to-end tests (M9)

| Test | Scope | Requires Stockfish + Python |
| ---- | ----- | --------------------------- |
| `analysis/tests/test_full_pipeline_e2e.py` | PGN → analysis → classify → plan | Yes |
| `spec/integration/full_workflow_pipeline_spec.rb` | Rails + Python full chain | Yes |
| `spec/system/mvp_workflow_spec.rb` | Browser happy path | Yes |

Run locally:

```bash
make test                    # all Rails + Python (integration specs skip without deps)
bundle exec rspec spec/integration/full_workflow_pipeline_spec.rb spec/system/mvp_workflow_spec.rb
cd analysis && PYTHONPATH=worker python -m pytest tests/test_full_pipeline_e2e.py -q
```

## CI job mapping

| Job | What runs | Stockfish / Python |
| --- | --------- | ------------------ |
| `test` | Full RSpec (integration/system specs skip without deps) | Chrome only |
| `test_python` | `make test-python` including `test_full_pipeline_e2e.py` | Yes |
| `workflow` | Pipeline + system specs only | Yes |

## Design principle audit (domain-models §24)

Rails controllers and views read **database status and artifacts only** — no in-process Python imports. Job coordination uses `system_jobs` rows and domain tables (`ImportBatch`, `AnalysisRun`, etc.). See [system-job-contract.md](../planning/system-job-contract.md).

## Manual-only scenarios

- Live Lichess OAuth (non-test mode)
- Docker worker polling latency and multi-worker behavior
- Full staging walkthrough: [m9-manual-testing.md](../manual-testing/m9-manual-testing.md)
