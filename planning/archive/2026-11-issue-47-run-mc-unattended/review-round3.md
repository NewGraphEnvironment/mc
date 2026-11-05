# Code-check round 3: branch 47 (HEAD f4aa693)

## Checklist read

- **code-check.md**: the prose of all 14 H3s under `## Mechanisms`, table rows skipped. I read these closely: "A guard that fails toward pass", "A fixture that cannot reach the failure mode", "A proxy is not the property", "Verification that reads its own output", "A guard's scope, escape hatches, and remedies", "A fix lands in one of two callers that share a harness", "Restore the bug and prove the guard fires", "Written data outlives the fix", "Serialization loses meaning silently", "One fact derived twice". From the rest of the file I read "Test a persistent change through its per-process override first". 22 of the 37 H3s not read.
- **code-check-r.md**: read "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone", "A library call that dispatches on a global option is not a pure function", "`system2(stdout = TRUE)` warns on a non-zero exit…", "A `function(...)` mock hides arguments…" and "`$` on a list partial-matches…". 111 of 116 not read.
- **code-check-shell.md**: read "Diagnose env/PATH problems in the shell that actually runs, not the ambient one" and "On this Mac `stat` and `date` are GNU…". 68 of 70 not read.
- **code-check-spatial.md**: read "A reader that accepts a UTC offset may not be applying it" and "An offset regex must be anchored to a time…", the only two about time zones. 92 of 94 not read.

## Mechanism

**The hypothesis holds in part.** The fire time is no longer derived separately in each place: `write_scheduled_args()`, `launchd_plist()`, `schedule_at()` and `target_label` all take it from one `send_time`. So "derived separately" is not what is still breaking.

**The mechanism.** Every form of the fact that is not an absolute instant is relative to some context, and nothing records or checks that context. The forms are wall-clock digits, display text, gargle's cache key and the account email. Their contexts are a zone, a tz database, a process environment and an option lookup. The writer renders each form in its own context, and the reader interprets it in its own. The code assumes the two contexts are the same. The two "lists that happen to agree" are:

- **"Machine-local" is four different zones, and they agree only by default.**
  1. The R session's zone: `TZ` at startup, `Sys.setenv()`, `withr::local_timezone()`.
  2. R's tz database. Measured on this Mac: R uses `/var/db/timezone/zoneinfo` only when `TZ` is unset. With `TZ` set to any value, including `America/Vancouver`, it switches to its bundled database. That database puts Vancouver at -0800 on 2026-11-05, where macOS has -0700.
  3. launchd's zone: the system's `/etc/localtime`, read when the job fires, not when it is scheduled.
  4. The zone of the Rscript that runs at fire time. That process gets no `TZ` from launchd, but does get one from `~/.Renviron`.

  `tz = ""` (round 2's fix) means zone 1 with database 2. The comment calls this "the machine's zone", which is true only when `TZ` is unset and the Mac has not changed zone since the send was scheduled.
- **"Who the send is for" has two derivations.** mc's is `default_from()`: `mc.from`, then `MC_FROM`. gmailr's, at fire time, is `gm_default_email()`: `GMAILR_EMAIL`, then `gargle_oauth_email`, then the first cached token if there is more than one.

The stale-send guard compares instants, so it is free of any context. But it checks in one direction only. It inherited the assumption that a backend can only fire late, because a missed fire while asleep was the case that motivated it. A context mismatch makes launchd fire early, and early passes the guard.

### Every place the mechanism reaches

| # | Place | Writer's context → reader's context | Verdict |
|---|---|---|---|
| 1 | `write_scheduled_args()` `.target_time` (R/mc_schedule.R:422) | epoch → epoch. jsonlite's default `digits = 4` keeps 4 decimals (`1793894400.1235`) | consistent |
| 2 | `run_scheduled_send()` guard (R/mc_schedule.R:338-351) | instant vs instant | instant-correct, **one-sided**: an early fire is sent (finding 1, 2) |
| 3 | `launchd_plist()` digits (R/mc_schedule.R:186) | R session zone + R tz db → launchd's system zone + macOS tz db, at fire time | **inconsistent** when `TZ` is set, or when the system zone changes before the fire (finding 1, 2) |
| 4 | `schedule_at()` `at -t` digits (R/mc_schedule.R:260) | R session zone → `at`, which inherits `TZ` through `system2()`'s environment and converts to an absolute time at submission | consistent on Linux, where R uses the system tz db |
| 5 | callr closure wait (R/mc_schedule.R:81-83) | `difftime()` on POSIXct | consistent |
| 6 | callr SKIPPED text (R/mc_schedule.R:88) | `format(target_time, "%H:%M:%S")` in the target's own `tzone`, no label | **inconsistent** with the round-2/parent display rule (finding 4) |
| 7 | fire-time SKIPPED text (R/mc_schedule.R:344) | the child process's zone, no label | **inconsistent** display (finding 4) |
| 8 | `target_label`: confirmation message and SCHEDULED `target=` (R/mc_deliver.R:107) | session zone, `%Z` | consistent. The comment's claim that this is "the zone the send log's own timestamps use" holds for lines written by the session, by `at` jobs and by callr children. It fails for launchd jobs when the session's `TZ` came from `Sys.setenv()`/withr |
| 9 | `send_log()` line timestamps (R/mc_deliver.R:265) | the writer process's zone, no label | mixed zones possible in one log in the case of #8; minor, pre-existing |
| 10 | test "launchd and at take the fire time's digits in the machine's zone" (tests/testthat/test-mc_schedule.R:525-551) | `withr::local_timezone()` moves the writer's zone, which `at` follows and launchd does not | correct for `at`; for launchd it **asserts the defect** (finding 1) |
| 11 | test SCHEDULED `%Z` (tests/testthat/test-mc_send.R:425-427) | numeric `send_at = 5` carries no zone | cannot reach "whatever zone send_at carried" (finding 5) |
| 12 | `mc_auth_check()` email key (R/mc_auth_check.R:56, 75) | `default_from()` → fire-time `gm_default_email()` | **inconsistent** (finding 3) |
| 13 | `auth_cache_dir()` (R/mc_auth_check.R:159) | mirrors gargle 1.6.1 `cache_establish()`: NA/TRUE → `rappdirs::user_cache_dir("gargle")` | consistent |
| 14 | cache filename `<hex>_<email>`, exact match (R/mc_auth_check.R:74-75) | gargle's `token_match()` does an exact `match2()` on hash_email when an email is given | consistent |
| 15 | client name via `auth_client()` | mirrors `gm_auth()`'s client resolution; scopes not compared | consistent (accepted: necessary, not sufficient) |
| 16 | `$HOME/.mc`, `$HOME/Library/LaunchAgents`, label prefix (schedule_launchd vs cleanup_scheduled_send) | the same literal, `HOME` read in each process | consistent unless the session overrode `HOME`; pre-existing |

## Findings

- **[severity: bug]** R/mc_schedule.R:186 (and 338-351). launchd fires at the wrong instant whenever the R session's zone or tz database differs from the system's, and when it fires early the send goes out.
  - **The mismatch.** `as.POSIXlt(target_time, tz = "")` renders the digits in R's session zone, using R's tz database. launchd reads them in the system zone, using macOS's database ("semantics similar to crontab(5)"; no `TZ` reaches PID 1). I did not create a real job, so launchd's side is documented, not measured. Measured with `launchd_plist()` from a temp copy, HOME in a temp dir, for a target of 2026-11-05 09:00 America/Vancouver:
    ```
    TZ unset          -> plist Day 5 Hour 9   (system rendering: /bin/date gives 09:00 MST)
    TZ=UTC            -> plist Day 5 Hour 17  -> launchd fires ~7-8 h late -> SKIPPED, never sent
    TZ=Pacific/Honolulu -> plist Day 5 Hour 7 -> launchd fires ~2-3 h EARLY
    ```
  - **An early fire is sent.** Measured: args written for `Sys.time() + 3 h`, then `run_scheduled_send()` with `mc_send` mocked, logs `STARTED`, `SENT`, and sends once. `late` is negative, and `late > grace` is the only check.
  - **This Mac makes it worse.** With `TZ` set to anything, even `TZ=America/Vancouver`, R switches to its bundled database (-0800 for Vancouver on 2026-11-05; macOS has -0700). So `TZ=America/Vancouver` in `~/.Renviron` alone moves a launchd send by an hour.
  - **The test pins it.** The round-2 test (test-mc_schedule.R:530-537) sets the session to Asia/Tokyo and asserts Tokyo digits in the plist. Those are exactly the digits a real launchd on a Vancouver Mac would fire 16 h off. The commit title "launchd and at fire at the target instant in any zone" is true for `at` and false for launchd.
  - **Rule:** code-check-r.md, "A library call that dispatches on a global option is not a pure function" (it names "anything reading `TZ`"); code-check-spatial.md, "A reader that accepts a UTC offset may not be applying it" (a fixture whose zone the writer shares; blind spot supplied by the machine); code-check.md, "A fixture that cannot reach the failure mode".
  - **Possible remedy.** Render the digits with the system's own zone machinery, independent of R's `TZ`. Verified from a `TZ=UTC` R session: `system2("/usr/bin/env", c("-u", "TZ", "/bin/date", "-r", sprintf("%.0f", as.numeric(target_time)), shQuote("+%Y %m %d %H %M")), stdout = TRUE)` returns `2026 11 05 09 00` for epoch 1793894400. Call `/bin/date` by absolute path, because GNU `date` is first on PATH here and reads `-r` differently. The `shQuote()` is needed: without it `system2()` splits the format and returns nothing. Then point the test at that rendering, not at `local_timezone()`.

- **[severity: fragile]** R/mc_schedule.R:338-351. The guard is one-sided, so a launchd fire before the target is sent even with `TZ` unset.
  - **The trigger.** launchd re-evaluates the calendar digits in whatever zone the system is in when the job fires. A Mac on automatic time zone that moves east between scheduling and firing (travel) fires early by the zone difference. `at` stores an absolute time and is unaffected.
  - **Why the guard misses it.** "Late" is not the only state that is not a deliberate resting place. The complement includes "early", which falls through to send.
  - **Rule:** code-check.md, "A guard that fails toward pass" ("Enumerate the complement rather than the known-bad states").
  - **Possible remedy.** Treat `late < -60` as its own case: 60 s covers launchd's whole-minute firing, which the accepted tradeoff already concedes. In that case, sleep until the target or skip and log it.

- **[severity: fragile]** R/mc_auth_check.R:56/75 vs R/mc_deliver.R:138-178 at fire time. `mc_auth_check()` validates a different "who" from the one an unattended send authenticates as.
  - **The two keys.** `mc_auth_check()` looks for a token keyed on `default_from()` (`mc.from` / `MC_FROM`). The fire-time process never calls `gm_auth(email = from)`. gmailr authenticates lazily with `gm_default_email()`, which is `GMAILR_EMAIL`, then `gargle_oauth_email`.
  - **The fallback.** When neither is set, gargle's `token_match()` (gargle 1.6.1, read from the installed namespace) uses a lone suitable token. With more than one, non-interactively, it does "Defaulting to the first email".
  - **The consequence.** `mc_auth_check()` can pass while a scheduled send authenticates as another account under the same client, or finds none.
  - **Scope.** Not new on this branch: fire-time auth has always worked this way. But `mc_auth_check()` is new and exists to certify unattended sends, and launchd is now the default.
  - **Rule:** code-check.md, "One fact derived twice"; "A proxy is not the property".
  - **Possible remedy.** Authenticate explicitly with `args$from` in `run_scheduled_send()` and in the callr closure. Or have `mc_auth_check()` also fail when `gm_default_email()` is set and differs from `email`.

- **[severity: fragile]** R/mc_schedule.R:88 and R/mc_schedule.R:344. The parent's display fix (machine-local, `%Z`) landed in `mc_deliver()` only. The two SKIPPED messages still print the target unlabelled:
  - the callr one in the target's own `tzone`;
  - the fire-time one in the child process's zone.

  So one send's SCHEDULED and SKIPPED lines can show different wall times for the same instant, with nothing saying why.
  - **Rule:** code-check.md, "A fix lands in one of two callers that share a harness".

- **[severity: fragile]** tests/testthat/test-mc_send.R:425-427. The new assertion's comment says "whatever zone send_at carried". But `send_at = 5` is numeric, so `send_time` has no `tzone`. Deleting `tz = ""` from R/mc_deliver.R:107 leaves the test green; only the `%Z` half is pinned.
  - **Rule:** code-check.md, "Restore the bug and prove the guard fires"; "A fixture that cannot reach the failure mode".
