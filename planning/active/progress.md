# Progress — Scheduled send (`send_at`) silently dropped (#36)

## Session 2026-05-08

- Plan-mode exploration of `R/mc_send.R` send_at block, send_log/notify/caffeinate helpers, existing tests, dependencies. Findings logged.
- Phases approved by user: 4 phases (safety patch → backend abstraction + launchd → at backend → release prep).
- Created branch `36-send-at-silent-drop` off `main`.
- Scaffolded PWF baseline (task_plan.md, findings.md, progress.md).
- Phase 1 complete: deprecation `warning()` on `send_at` non-NULL, SCHEDULED log entry at submission, STARTED log entry at fire time. `@details` updated with lifecycle caveat + log heartbeat documentation. 2 new test_that blocks (5 expectations). Full suite 307 pass / 0 fail / 0 warn. Lint clean.
- Phase 2 complete: backend abstraction landed. New `R/mc_schedule.R` with dispatcher (`schedule_send`), `resolve_scheduler` (auto → launchd/at/error), `schedule_callr` (refactor of existing inline code), `schedule_launchd` (writes plist + args JSON, launchctl load), `launchd_plist` helper, `schedule_at` Phase 3 stub, `run_scheduled_send` fire-time entry point, `cleanup_scheduled_send`, `generate_send_uuid`. `mc_send` gains `scheduler = c("callr", "auto", "launchd", "at")` arg with `match.arg`; default `"callr"` preserves back-compat. Warning now scoped to `scheduler == "callr"` only. 12 new test_that blocks. Full suite 351 pass / 0 fail / 0 warn. Lint clean.
- Next: Phase 3 — Linux `at` backend.
