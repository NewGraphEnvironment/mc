# Code-check round 2: review of the round-1 fixes (#47)

## Checklist read

- **code-check.md:** all 14 `## Mechanisms` H3s, prose only (A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice). Not read: 23 (Rules that stand alone, Security, Spreadsheets and PDFs).
- **code-check-r.md:** read 9: `$` on a list partial-matches…; as.POSIXct on a Date pins UTC midnight…; `system2(stdout = TRUE)` warns on a non-zero exit…; `tolerance` in testthat is RELATIVE…; A `function(...)` mock hides arguments…; Under `R CMD check`, tests run from a temp dir…; `on.exit()` at a script's top level never fires; A database driver's value is not a base R type…; `paste()` with a zero-length argument…. Not read: 107.
- **code-check-shell.md:** read 1: A `pgrep -f` waiter matches its own command line…. Not read: 69.
- **code-check-spatial.md:** read 0 (the diff uses no spatial tools). Not read: 94.

## Findings

- **[severity: bug]** R/mc_schedule.R:185 and R/mc_schedule.R:259: launchd and at fire on the wrong instant when `send_at` carries a time zone other than the machine's, and the new stale-send guard now skips those sends every time.
  - `launchd_plist()` takes the hour and minute from `as.POSIXlt(target_time)`, and `schedule_at()` takes `format(target_time, "%Y%m%d%H%M.%S")`. Both use the POSIXct's own `tzone`, but launchd and `at` read the digits as machine-local time.
  - The guard added in round 1 compares epoch instants (`.target_time = as.numeric(target_time)`). So the fire time is derived twice and the two derivations disagree.
  - Measured with `TZ=America/Vancouver` and `send_at = as.POSIXct("2026-11-05 09:00", tz = "UTC")` (`lubridate::ymd_hm()` returns UTC by default). The plist says Hour 9, so launchd fires at 09:00 PST. The target instant is 01:00 PST. Running `run_scheduled_send()` at the fire instant (Sys.time mocked) logged `SKIPPED … Fired 480 min past target time`, and `mc_send` was called 0 times.
  - With a zone west of the machine's, the job fires early instead and sends early, which the guard cannot see.
  - Before this branch the default was callr, which honours the instant through `difftime()`, so this path is now the default one. The confirmation message at R/mc_deliver.R:106 prints the time in the target's zone ("09:00"), so the user sees nothing wrong.
  - The existing test (tests/testthat/test-mc_schedule.R:112-145) builds its target with `tz = "UTC"` and derives the expected digits with the same `as.POSIXlt(target)`, so it cannot disagree with the code.
  - Fix: `as.POSIXlt(target_time, tz = "")` in `launchd_plist()` and `format(target_time, "%Y%m%d%H%M.%S", tz = "")` in `schedule_at()`. The test should then use a non-local zone and expect local digits.
  - **Rule:** code-check.md "One fact derived twice"

- **[severity: fragile]** R/mc_schedule.R:139, R/mc_schedule.R:249 and R/mc_schedule.R:333-336: the new writer adds `.target_time` and `.grace_secs` to the args JSON, and an older `run_scheduled_send()` passes them straight into `mc_send()`. `mc_send()` has no `...`, so that is an `unused arguments` error, and the send is logged FAILED at fire time.
  - The fired job runs the **installed** mc (`Rscript -e 'mc:::run_scheduled_send(...)'`), not the session that scheduled it.
  - Measured on this machine: the installed mc is 0.3.0 (`~/Library/R/arm64/4.5/library/mc`, RemoteSha f5231b8), and its `run_scheduled_send` has no strip.
  - So any send scheduled from a `load_all()` session of this branch before the package is installed fails when it fires. launchd is now the default, so this happens without naming a scheduler.
  - Before this change the JSON held only `mc_send()` formals, so a version mismatch was harmless.
  - Once the release is installed, writer and reader are the same version. The exposure is the dev and test window, plus any machine where the session's library differs from the one Rscript uses.
  - Options: say so in the PR (install before scheduling), or carry the fire window in a sidecar file the old reader ignores (cleanup would then need to remove it).
  - **Rule:** code-check.md "Written data outlives the fix"

- **[severity: fragile]** tests/testthat/test-mc_schedule.R:500 and :463: no test pins the precision of the epoch the production writer stores.
  - `expect_equal(back$.target_time, as.numeric(target), tolerance = 1e-6)` is relative, so it accepts about ±1794 s at today's epoch, which is six times the 300 s grace.
  - The `run_with_target()` helper writes its JSON with `digits = NA`, not the production writer's defaults, so it never goes through `with_fire_window()` and `write_json()` as shipped.
  - Mutation in a temp copy: `with_fire_window()` storing `round(as.numeric(target_time), -3)` (up to 500 s wrong) left test-mc_schedule.R at 0 failed and 0 errors.
  - Production is correct today: jsonlite 2.0.0's default `digits = 4` counts decimal places. `1793850022.841151` round-tripped as `1793850022.8412`, an error of 4.9e-5 s.
  - So this is a guard that cannot fire, not a live defect. Compare the absolute difference instead, e.g. `expect_lt(abs(back$.target_time - as.numeric(target)), 1)`.
  - **Rule:** code-check-r.md "`tolerance` in testthat is RELATIVE, so it pins a published figure far more loosely than it looks"

## Checked and clean

- **JSON round trip.** As measured above, an integer-valued epoch reads back as an integer (below 2^31), and `as.POSIXct(<int>, origin = "1970-01-01")` is fine. The origin is parsed in GMT on both old and new R, so the instant is independent of the zone. `format(target)` in the log message is display only.
- **`$` partial matching.** The JSON keys are `to, subject, cc, bcc, from, thread_id, to_self, sig, sig_path, attachments, labels, labels_create, html` (plus the two dot keys). No key extends `.target_time` or `.grace_secs`, so on old JSON `args$.target_time` is NULL and not a sibling. `args$x <- NULL` (`$<-`) is exact. `args$to` and `args$subject` are always present.
- **Old-version JSON.** It has no `.target_time`, so it is not checked and sends as before, as the comment documents. Note that launchd ignores the plist `Year` key, so an un-fired old job re-fires a year later and still sends. That predates this branch.
- **Strip coverage.** `run_scheduled_send()` is the only reader of the JSON. callr gets its window as separate `r_bg` args. A mutation deleting `args$.target_time <- NULL` reddens "sends within grace and strips the fire window".
- **Cleanup on the skip path.** `on.exit(cleanup_scheduled_send(...))` is registered before the guard, and the `return()` runs it. The test asserts it, and mutating the guard to `if (FALSE)` reddens 2 tests.
- **pgrep.** `pgrep -x atd` (not `-f`) is called only where `Sys.which("pgrep")` finds it. The status is read from `attr(, "status")` with warnings suppressed, and a NULL status means running. The test mocks it.
- **mc_auth_check exact match.** `sub("^[0-9a-f]+_", "", files) == email` removes only the leading hex hash, because the class cannot cross `_`. This matches gargle's own `token_match()`, which matches the whole email exactly. A mixed-case `MC_FROM` misses in both, consistently.
- test-mc_schedule.R (0 failed, 0 errors, 0 skipped) and test-mc_auth_check.R (0 failed, 0 errors, 0 skipped) pass in a temp copy with HOME at a temp dir.
