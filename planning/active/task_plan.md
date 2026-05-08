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

- [ ] Create `R/mc_schedule.R` with: `schedule_send()` dispatcher, `schedule_callr()` (refactor of existing inline code, behavior preserved), `schedule_launchd()`, `run_scheduled_send()`.
- [ ] `schedule_launchd(target_time, args)`:
  - Serialize `args` to `~/.mc/scheduled/<uuid>.json` via `jsonlite::write_json`.
  - Generate launchd plist Label `com.newgraph.mc.send-<uuid>`.
  - Write plist to `~/Library/LaunchAgents/<label>.plist` with `StartCalendarInterval` matching `target_time` and `ProgramArguments = ["/usr/bin/env", "Rscript", "-e", "mc:::run_scheduled_send('<args-path>')"]`.
  - `system2("launchctl", c("load", "-w", plist_path))`.
- [ ] `run_scheduled_send(args_json_path)`:
  - Read args JSON, log `STARTED`, call `mc_send(..., send_at = NULL)`, log `SENT`/`FAILED`.
  - Cleanup: `launchctl unload` + `unlink` plist + args JSON.
- [ ] Add `scheduler = "callr"` arg to `mc_send()` (default `"callr"` for back-compat). Validate with `chk::chk_string` + enum check. Replace current inline `callr::r_bg` code with `schedule_send(target_time, args, scheduler)`.
- [ ] Thread `scheduler` through scheduled-send recursive call.
- [ ] New tests in `test-mc_schedule.R`:
  - `schedule_launchd` writes a parseable plist with correct fire time + ProgramArguments
  - cleanup logic invoked after `run_scheduled_send` returns (mocked `launchctl` + `unlink`)
  - `run_scheduled_send` round-trip: read args, call mc_send, log entries land correctly
  - skip launchd-specific tests on non-macOS via `skip_on_os("windows", "linux")`
- [ ] New unit test in `test-mc_send.R`: `scheduler = "auto"` resolves to `launchd` on Darwin (mock `Sys.info`).
- [ ] `devtools::document()`, `devtools::test()`, `lintr::lint_package()` clean.
- [ ] `/code-check` on staged diff.
- [ ] Atomic commit including checkbox flips.

## Phase 3: Linux `at` backend

- [ ] `schedule_at(target_time, args)`:
  - Serialize args to `~/.mc/scheduled/<uuid>.json` (same pattern).
  - Pipe `Rscript -e "mc:::run_scheduled_send('<args-path>')"` into `at -t YYYYMMDDHHMM.SS` via `system2` with `input = ...`.
  - Capture `at` job number from stderr if available (for diagnostic logging).
- [ ] Auto-dispatch in `schedule_send`: `Sys.info()["sysname"] == "Linux"` → `at` backend.
- [ ] New tests in `test-mc_schedule.R`:
  - `schedule_at` invokes `at` with correctly formatted time string and stdin Rscript invocation (mock `system2`, capture args)
  - skip on non-Linux via `skip_on_os("mac", "windows")`
- [ ] `devtools::document()`, `devtools::test()`, `lintr::lint_package()` clean.
- [ ] `/code-check` on staged diff.
- [ ] Atomic commit including checkbox flips.

## Phase 4: Docs + release prep

- [ ] Update `@details` of `mc_send` to document `scheduler` arg + per-OS backend behavior + the deprecation steering toward `"auto"`.
- [ ] Add `# mc 0.2.10` block at top of `NEWS.md` covering: deprecation warning, heartbeat logging, `scheduler` arg, launchd backend, at backend.
- [ ] `DESCRIPTION` Version: `0.2.9` → `0.2.10`. Confirm `jsonlite` in Imports; add if missing.
- [ ] Full `devtools::document()`, `devtools::test()` (≥302 baseline + new tests), `lintr::lint_package()` clean.
- [ ] `/code-check` on staged diff.
- [ ] Atomic commit including checkbox flips.

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
