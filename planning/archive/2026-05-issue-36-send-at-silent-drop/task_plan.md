# Task: Scheduled send (`send_at`) silently dropped — process lifecycle reliability (#36)

## Problem

The 2026-05-07 NRP email scheduled via `mc_md_send(..., override = list(draft = FALSE, send_at = 15))` never sent. Silent failure: no entry in `~/.mc/send_log.txt`, no FAILED or SKIPPED notification. Root cause: `callr::r_bg` child gets cleaned up when the parent `Rscript -e` invocation exits, taking the scheduled send with it. Caffeinate exits silently when its watched PID disappears, so nothing surfaces the failure to the user.

The fix has two halves: immediate safety (deprecation warning + heartbeat log entries so missed fires are auditable) and structural durability (OS-native scheduling via `launchd` / `at` that owns its lifecycle independent of any R session).

## Design

Three additions to `R/mc_send.R`, with a new helper file for the OS-native backends:

1. **`scheduler` parameter on `mc_send()`** — character, one of `"callr"` (current default, preserves back-compat) or `"auto"` (detects OS, picks `launchd` on Darwin / `at` on Linux). Future PR can flip the default to `"auto"` once both backends prove stable.
2. **Internal dispatcher** — `schedule_send(target_time, args, scheduler)` routes to the chosen backend.
3. **`run_scheduled_send(args_json_path)` helper** — single entry point that the OS-native backends invoke via `Rscript -e 'mc:::run_scheduled_send(...)'`. Reads serialized args, calls `mc_send(..., send_at = NULL)`, handles logging.

`send_log()` extended (purely additive — already accepts arbitrary status string) to emit `SCHEDULED` at submission and `STARTED` at fire time. Heartbeat works regardless of which scheduler is active so missed fires are auditable from `~/.mc/send_log.txt` alone.

## Phase 1: Deprecation warning + heartbeat logging

- [x] Emit `warning()` when `send_at` is non-NULL noting unreliable lifecycle in some call contexts (Rscript one-shot, RStudio sessions that exit, CI). Points at #36 and recommends `scheduler = "auto"` once it lands.
- [x] Add `send_log("SCHEDULED", to, subject, target_time)` call at submission time, just before `callr::r_bg(...)` in `R/mc_send.R`.
- [x] Add `send_log("STARTED", to, subject)` call at fire time inside the callr inner function (after `Sys.sleep` + missed-window check, before the recursive `mc::mc_send` call).
- [x] Updated `@details ## Scheduled send` section in `mc_send` roxygen with a "Lifecycle caveat (mc#36)" subsection documenting the silent-drop risk + the heartbeat log entries.
- [x] Updated `send_log` `@param status` docstring to include SCHEDULED + STARTED.
- [x] New tests in `test-mc_send.R`:
  - deprecation warning emitted on `send_at` non-NULL (`mc_send warns when send_at is non-NULL`)
  - SCHEDULED log entry appears at submission with `target=` detail (`mc_send writes SCHEDULED log entry at submission time`)
- [x] `devtools::document()`, `devtools::test()` (307 pass, 0 fail, 0 warn), `lintr::lint_package()` clean for changed files.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Phase 2: Backend abstraction + macOS launchd

- [x] Created `R/mc_schedule.R` with: `schedule_send()` dispatcher, `resolve_scheduler()` (auto → OS-native), `schedule_callr()` (refactor of existing inline code, behavior preserved), `schedule_launchd()`, `launchd_plist()` helper, `schedule_at()` (Phase 3 stub that errors with clear message), `run_scheduled_send()`, `cleanup_scheduled_send()`, `generate_send_uuid()`.
- [x] `schedule_launchd`: serializes args to `~/.mc/scheduled/<uuid>.json`, writes plist to `~/Library/LaunchAgents/<label>.plist` with `StartCalendarInterval` + `ProgramArguments = [Rscript, -e, mc:::run_scheduled_send("<args>")]`, `RunAtLoad = false`, stdout/stderr to `~/.mc/scheduled/<label>.{out,err}`. Loads via `launchctl load -w`.
- [x] `run_scheduled_send`: reads args JSON, logs `STARTED`, calls `mc_send(send_at = NULL)`, logs `SENT`/`FAILED`, fires `send_notify`. `on.exit(cleanup_scheduled_send(...))` ensures plist + args + log files are removed regardless of outcome.
- [x] `cleanup_scheduled_send`: macOS-only `launchctl unload -w` + plist unlink + stdout/stderr unlink. Args JSON unlink unconditional. Idempotent.
- [x] Added `scheduler = c("callr", "auto", "launchd", "at")` arg to `mc_send()` with `match.arg` validation. Default `"callr"` preserves back-compat. Replaced inline `callr::r_bg` code with `schedule_send(send_time, schedule_args, scheduler)` dispatch.
- [x] Warning on `send_at` is now scoped to `scheduler == "callr"` only (auto/launchd/at don't have the lifecycle issue, so no warning needed when user opts into them).
- [x] New tests in `test-mc_schedule.R` (12 test_that blocks):
  - resolve_scheduler passthrough + auto-mapping (Darwin → launchd, Linux → at, Windows → error)
  - schedule_at Phase 3 placeholder errors
  - launchd_plist embeds Label, ProgramArguments, StartCalendarInterval, RunAtLoad correctly
  - schedule_launchd writes plist + args JSON, invokes launchctl load (skip on non-macOS)
  - run_scheduled_send round-trip: reads args, calls mc_send with send_at = NULL, logs STARTED + SENT, notifies, cleans up
  - run_scheduled_send logs FAILED on error path
  - cleanup_scheduled_send idempotent
  - mc_send rejects invalid scheduler value
- [x] `devtools::document()`, `devtools::test()` (351 pass, 0 fail, 0 warn), `lintr::lint_package()` clean for changed files.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Phase 3: Linux `at` backend

- [x] `schedule_at(target_time, args)`: serializes args to `~/.mc/scheduled/<uuid>.json`, pipes `Rscript -e 'mc:::run_scheduled_send("<args-path>")'` into `at -t YYYYMMDDhhmm.ss` via `system2(..., input = ...)`. Captures `at` job number from stderr (`"job N at <time>"`) for diagnostic logging. On non-zero status, unlinks args + stops with the `at` error message.
- [x] Auto-dispatch already wired in Phase 2 (`resolve_scheduler` returns `"at"` on Linux).
- [x] Documented `atd` daemon assumption in the schedule_at docstring (silent failure mode if atd not running — verify with `systemctl is-active atd`).
- [x] New tests in `test-mc_schedule.R`:
  - `schedule_at` writes args JSON, pipes Rscript invocation to `at`, parses job_id, returns handle (cross-platform, system2 mocked)
  - `schedule_at` cleans up args JSON and stops on `at` command failure (cross-platform, system2 mocked)
- [x] `devtools::document()`, `devtools::test()` (364 pass, 0 fail, 0 warn), `lintr::lint_package()` clean for changed files.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Phase 4: Docs + release prep

- [x] `@details ## Scheduled send` already documents `scheduler` arg + per-OS backend behavior + the deprecation steering toward `"auto"` (landed inline in Phases 1–2).
- [x] Added `# mc 0.2.10` block at top of `NEWS.md` covering: `scheduler` arg + OS-native backends (launchd / at), heartbeat logging (SCHEDULED / STARTED), deprecation warning on callr path, internal HTML pre-render, new `R/mc_schedule.R` module.
- [x] `DESCRIPTION` Version: `0.2.9` → `0.2.10`. `jsonlite` confirmed in Imports (line 35).
- [x] Full `devtools::document()`, `devtools::test()` (364 pass, 0 fail, 0 warn), `lintr::lint_package()` clean for changed files.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Validation

- [ ] All existing tests still pass (≥302 PASS baseline from 0.2.9).
- [ ] New unit tests pass for deprecation warning, heartbeat logging, scheduler dispatch, launchd backend, at backend.
- [ ] `lintr::lint_package()` clean.
- [ ] `/code-check` clean on each phase commit.
- [ ] **Manual verification on macOS:** `mc_md_send` a test draft with `scheduler = "auto"` and `send_at = 2`. Confirm: SCHEDULED log entry, plist appears in `~/Library/LaunchAgents/`, fires at target time even with R session closed, STARTED + SENT log entries appear, plist + args JSON cleaned up.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.
- [ ] `/gh-pr-merge` for NEWS finalization, tag, post-merge CI watch.

## Open questions / deferred

- Default `scheduler = "callr"` preserves back-compat in this PR. Future PR can flip default to `"auto"` once `launchd` + `at` backends prove stable in production. Don't change the default in this work.
- `at` may be disabled by default on macOS — not relevant since macOS uses launchd. Linux VMs typically have `atd` running; if not, the backend will surface the underlying error from `at` and the user can enable it.
- Windows scheduling not in scope. The dispatcher will error with "scheduler 'auto' not supported on Windows; use 'callr' explicitly" until someone needs it.
- `lifecycle::deprecate_warn` vs plain `warning()` — going with plain `warning(call. = FALSE)` since mc has no existing `lifecycle` dependency and the convention has been plain warnings.
