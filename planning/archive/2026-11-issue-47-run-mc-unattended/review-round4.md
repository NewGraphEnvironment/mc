# Code-check round 4 (#47): round-3 fixes, and whether the context mechanism is closed

Reviewed: `round3-fixes.diff` hardest, then the whole `branch.diff`; current `R/mc_schedule.R`,
`R/mc_deliver.R`, `R/mc_auth_check.R`, `R/mc_send.R`, the changed tests. Probes ran in a copy of
the package under the session scratchpad (`r4/pkg`), with HOME pointed at a temp dir and `system2`
mocked or shimmed. No real launchd or at job was created and nothing was sent.
`test-mc_schedule.R` in the copy: 27 blocks, 0 failed, 0 error.

## Checklist read

- **code-check.md**: the prose of all 14 H3s under `## Mechanisms` (A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice). Not read: 24.
- **code-check-r.md**: `system2(stdout = TRUE)` warns on a non-zero exit instead of raising…; as.POSIXct on a Date pins UTC midnight…; Under `R CMD check`, tests run from a temp dir against the INSTALLED package; A `function(...)` mock hides arguments…; Tests that silently do not run; `on.exit()` at a script's top level never fires; A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared; testthat counts an uncaught error under `error`, not `failed`. Not read: 108.
- **code-check-shell.md**: On this Mac `stat` and `date` are GNU, so the same flag letter means something else; BSD vs GNU sed/grep portability; A verification command can be shadowed by a shell function or alias; Quoting; Paths; Diagnose env/PATH problems in the shell that actually runs. Not read: 64.
- **code-check-spatial.md**: An offset regex must be anchored to a time…; A reader that accepts a UTC offset may not be applying it. Not read: 92.

## Round-3 fixes: the questions asked

**`system_wall_clock()` under a different HOME, PATH, locale or TZ.** It holds up. In the copy:
`HOME` unset, `PATH=""`, `LC_ALL=ja_JP.UTF-8`, `LANG=ar_SA.UTF-8` and `TZ=Asia/Tokyo` each
returned `2026 11 5 2 0` for 2026-11-05 09:00Z, which is the system zone (America/Vancouver, MST, UTC-7
in this tzdata). Both binaries are absolute and `%Y %m %d %H %M` always writes ASCII digits.
`system()` goes through `/bin/sh -c`, which a non-interactive shell runs without reading a profile.

**Negative or fractional epochs.** A fractional value is floored: 09:00:00.9 gave minute 0.
`/bin/date -r -1` works (it prints 1969-12-31 15:59), but no negative epoch can arrive, because
`resolve_send_at()` refuses a time that is not in the future.

**DST minutes.** An instant always maps to a local minute that exists, so a nonexistent
(spring-forward) minute cannot be produced. A repeated (fall-back) minute can:
`TZ=America/Toronto /bin/date -r` gives `2026 11 01 01 30` for both 05:30Z (EDT) and 06:30Z (EST).
launchd can resolve those digits to only one of the two instants. If it picks the earlier one, a
target on the second occurrence fires an hour early and the new wait covers it. If it picks the
later one, a target on the first occurrence fires an hour late and is SKIPPED. That loses the send
but fails safe (see finding 4).

**Early-fire `Sys.sleep()`.**
- `late` cannot be NA: the writer stores `as.numeric()` of a non-NA POSIXct, and a missing key is
  `NULL`, which is never checked.
- A negative `late` is the case the wait is for. `late` is measured again on `Sys.time()` (the wall
  clock) after the sleep. So a sleep that overshoots for any reason, the machine sleeping
  included, ends in either a send inside the grace period or a SKIPPED entry, never a stale send.
- Very long waits are reachable. A zone change after scheduling is one route. The other is a target
  more than a year out: `man launchd.plist` lists no `Year` key, so launchd ignores it and fires on
  the first matching month/day/hour/minute. In both cases the wait is better than what the round-2
  code did, which sent early.
- Residual: a logout or shutdown during the wait sends SIGTERM, so `on.exit()` does not run and the
  log keeps only SCHEDULED. The plist reloads at the next login and fires again a year later, when
  the send is SKIPPED. This is safe and needs no change.
- Probe: `send_at = 0.05` through the real `run_scheduled_send()` slept about 3 s and then ran.

## Enumeration

Every place in `R/` where a time, a zone, a working directory, a library path or an account
identity crosses a process or tool boundary:

| # | Boundary | What crosses | Verdict |
|---|---|---|---|
| 1 | R → launchd plist `StartCalendarInterval` | wall-clock digits | **Consistent.** The system zone, read by system `date` with TZ unset, is the zone launchd reads at fire time. Residuals all fail safe, early through the wait and late through SKIPPED: a system-zone change between scheduling and firing (inherent to launchd's wall-clock API); the fall-back hour (finding 4); the ignored `Year` key (pre-existing). |
| 2 | R → launchd plist `ProgramArguments` | Rscript path, args JSON path | **Consistent.** Both are absolute, resolved at scheduling. |
| 3 | R → launchd job working directory | the cwd relative paths resolve against | **Inconsistent: finding 1.** The plist has no `WorkingDirectory`, so the job runs in `/`. |
| 4 | R → launchd job environment and library | env vars, `.libPaths()` | **Inconsistent: findings 1 and 2.** The job has launchd's environment plus `~/.Renviron` and `~/.Rprofile`, not the session's exports, and no `R_LIBS`. |
| 5 | R → `at` time | `format(tz = "")` digits | **Consistent.** `at` inherits R's TZ and stores an absolute time. Residual: the fall-back hour (finding 4). `at` drops seconds, so it fires up to 59 s early and the wait covers it. |
| 6 | R → `at` job context | cwd, environment, umask | **Consistent.** `at` keeps all three from submission, so the fire-time process matches the session. |
| 7 | R → JSON → fire-time R | `.target_time` (epoch, written to 4 decimals: `1793851175.9445`), `.grace_secs`, `from`, `to`, `html` | **Consistent.** Instants carry no zone, and `from` is serialized, so `MC_FROM` is not needed at fire time. `attachments` is the exception, carried as written: finding 1. |
| 8 | R → callr child | POSIXct (RDS), env, cwd, libpath | **Consistent.** The child inherits env and libpath. Its cwd is the parent's (measured: `getwd()` in an `r_bg` child returned the parent's directory). |
| 9 | R → console message and SCHEDULED detail | target time | **Consistent.** The session zone, with `%Z` named. |
| 10 | Fire-time R → SKIPPED messages (callr and OS-native) | target time | **Consistent.** The fire-time zone, with `%Z` named. |
| 11 | Session and fire-time R → `send_log` line timestamps | `Sys.time()` digits, no zone | **Inconsistent for launchd: finding 3.** |
| 12 | `mc_auth_check()` → gargle cache | email (exact filename match), client id and name | **Matching is fine. Context is not: finding 2.** The client name, cache directory and loaded rlang come from the calling session, not from the process that will authenticate. |
| 13 | Fire-time R → gmailr auth | account (`GMAILR_EMAIL` / `gargle_oauth_email`) | **Accepted tradeoff** (it is not `from`). The advice to set `GMAILR_EMAIL` reaches a launchd job only through `~/.Renviron`: finding 2. |

So the mechanism is **not closed**. It recurs one axis over, in the working directory, the
library path and the environment of the launchd job. The time axis itself (rows 1, 5, 7, 9, 10)
is now consistent, and its remaining residuals all fail safe.

## Findings

1. **[bug]** `R/mc_deliver.R:118-124` and `R/mc_schedule.R:182-217`: a relative `attachments` path breaks a scheduled send, now that launchd is the macOS default.
   - The path is checked against the session's cwd at scheduling (`mc_deliver.R:68-77`) and passes.
   - It is serialized as written. The plist sets no `WorkingDirectory`, so the launchd job runs in `/`.
   - At fire time `mc_deliver()` checks it again, now against `/`, and the send FAILS.
   - The old default, callr, inherited the cwd (measured), and so does `at`. This bug is new on this branch for every macOS user who did not name a scheduler.
   - Evidence that launchd runs unsandboxed agents in `/`: `lsof -d cwd` on this Mac shows `/` for `usernoted` and `universalaccessd`.
   - Reproduced in the copy: scheduled from `proj/` with `attachments = "report.txt"`, then `setwd("/")` and the real `run_scheduled_send()`. Log: `STARTED`, then `FAILED | Attachment file(s) not found: report.txt`. Nothing was sent.
   - The library path has the same gap. A user whose `mc` lives in an renv project library, or under a shell-exported `R_LIBS`, gets a fire-time `mc` from the user library: none at all (Rscript errors, nothing in `send_log`), or an older `mc` that rejects the new JSON keys. This is a wider route to the accepted "older installed mc" tradeoff than `load_all()`.
   - Fix: `attachments <- normalizePath(attachments, mustWork = TRUE)` before `schedule_args`. Optionally also write `WorkingDirectory` (`getwd()`) and an `EnvironmentVariables` `R_LIBS` (`.libPaths()`) into the plist, so the launchd job sees what callr and `at` already carry.
   - **Rule:** none named; it is round 3's mechanism (a context-dependent form rendered in the writer's context and read in another's), one axis over. The tests miss it under code-check.md, "A fixture that cannot reach the failure mode": every schedule test runs in one cwd.

2. **[fragile]** `R/mc_auth_check.R:65-76` (and the README Troubleshooting block, and the roxygen added in round 3): `mc_auth_check()` checks the calling session's context, not the context of the process that will send.
   - In the session it reads `auth_client()` (an in-session `gm_auth_configure()` client, or `GMAILR_OAUTH_CLIENT` as exported to this session), `auth_cache_dir()` (an in-session `gargle_oauth_cache` option) and the rlang that is loaded.
   - A launchd job sees only launchd's environment plus `~/.Renviron` and `~/.Rprofile`. Checked: `launchctl getenv TZ` is empty, and shell exports never reach it.
   - So the check can pass while the unattended send fails with "Can't get Google credentials". Three ways:
     - `GMAILR_OAUTH_CLIENT` is exported in a shell profile rather than `~/.Renviron`.
     - The cache option is set in-session only.
     - The motivating case: an RStudio session started before an rlang upgrade still has the old rlang loaded, computes the old client name, and matches the old token. The README sends users to run `mc_auth_check()` in exactly that session. Its own text concedes that a pre-upgrade session writes the old name, but applies that only to the fix, not to the check.
   - The round-3 advice "Set `GMAILR_EMAIL`" is a remedy that works only if it lands in `~/.Renviron`.
   - Fix: run the check in a fresh process (`callr::r(function(e) mc::mc_auth_check(e), list(email))`, or `Rscript -e`), or at least say in the description and README to run `Rscript -e 'mc::mc_auth_check()'`, and to put `GMAILR_EMAIL`, `GMAILR_OAUTH_CLIENT` and any `gargle_oauth_cache` option in `~/.Renviron` or `~/.Rprofile`.
   - **Rule:** code-check.md, "A proxy is not the property" (the property is whether the fire-time process finds the token, and the check tests whether this session finds it); also code-check.md, "A guard's scope, escape hatches, and remedies" (a remedy is code the caller will run, and this one does not reach the consumer).

3. **[fragile]** `R/mc_deliver.R:264-265` (`send_log()` line timestamp): log lines carry no zone, and the default backend now writes them from two different zone contexts.
   - SCHEDULED is stamped in the session's zone. STARTED, SENT, FAILED and SKIPPED come from the launchd job, which has no TZ and so uses the system zone (unless `~/.Renviron` sets one).
   - With TZ set in the session (exported in a terminal, or `Sys.setenv`), the two zones differ, and a reader auditing "SCHEDULED with no STARTED" compares digits from two zones with nothing to say so.
   - Under the old callr default, and under `at`, the child inherits TZ, so this did not arise.
   - The comment at `mc_deliver.R:105-106` ("the zone the send log's own timestamps use") is true of the SCHEDULED line only.
   - Fix: add `%Z` to the line timestamp (no code parses `send_log.txt`), or write it in UTC.
   - **Rule:** code-check.md, "Serialization loses meaning silently" ("Prefer the record over the rendering").

4. **[fragile, low]** `R/mc_schedule.R:186` (launchd) and `:260` (at): a target in the fall-back hour maps to wall-clock digits that occur twice.
   - Measured: `01:30` for both 05:30Z (EDT) and 06:30Z (EST), America/Toronto, 2026-11-01.
   - The backend resolves the digits to one instant. If that is the earlier, the round-3 wait handles it. If the later, a first-occurrence target is SKIPPED: once a year, one hour wide, logged and notified.
   - For `at` there is a cheap disambiguation: pass UTC digits to an `at` invoked with `TZ=UTC`, and restore the session's TZ in `job_cmd`, since `at` captures the environment.
   - For launchd there is none short of a different trigger.
   - Report only so it is a decision rather than an accident.
   - **Rule:** none.

Notes, not findings:
- The `cleanup_scheduled_send()` roxygen says the dormant launchd entry "never re-fires". With no `Year` key it re-fires a year later and errors on the deleted JSON. That is harmless and pre-existing.
- If `system_wall_clock()` stops, the args JSON written just before it stays in `~/.mc/scheduled`, and the log has SCHEDULED with no STARTED, which is the same pattern as an existing launchctl failure.

## Verdict

Not clean: one bug (relative attachments and library under the launchd default) and three fragile
items. The round-3 time fixes are correct and hold under every perturbation tried.
