## Outcome

Move 1 of 3 (#47, with #8 and #38): mc running from `Rscript`, cron or CI rather than an interactive session.

**R CMD check passes on a runner with no sender and no Gmail credentials.** The R-CMD-check workflow from #46 is folded in.
- Two of the three test errors were lookup order: `mc_deliver()` forced `default_from()` before its path/html check.
- The third was a real bug, not missing credentials. `mc_thread_modify()` matched system labels case-sensitively while `resolve_label_names()` did not, so `"Starred"` fetched user labels. No test was skipped.
- Both WARNINGs (non-ASCII strings, undocumented `...`) are cleared.

**`scheduler` defaults to `NULL`**, which resolves to launchd on macOS and `at` on Linux, and to callr elsewhere.

**New export `mc_auth_check()`** compares a cached gmailr token's client name with the session's. gargle derives the name from `rlang::hash()`, which changed in rlang 1.3.0.

**What we learned: the scheduler default was the hard part.** Five `/code-check` rounds each found the same mechanism one axis further out. A form of a send's time or context was rendered in the scheduling session's context and read in the fired job's:
- the zone of launchd's and `at`'s wall-clock digits;
- R's session `TZ`, and its bundled tz database, against launchd's system zone;
- a launchd job's working directory `/`, against relative attachment paths;
- `normalizePath()` renaming a symlinked attachment;
- `character(0)` becoming `list()` through JSON.

The OS-native backends also gained the stale-send guard callr already had, plus early-fire waiting.

## Measurement

- **CI before:** 3 test ERRORs and 2 WARNINGs (run 40595587897).
- **CI after, local equivalent:** `rcmdcheck --as-cran` with no sender, no OAuth client and no token cache gave 0 errors, 0 warnings and 2 NOTEs (a redirected URL; the deliberate `:::` in the callr child).
- **Unit tests:** 208, 0 failures. **Integration:** 12, 0 failures.
- **Round 2 reproduction:** `send_at = as.POSIXct("2026-11-05 09:00", tz = "UTC")` on a Pacific machine wrote plist Hour 9 against a target of 01:00 local, so the fired job logged `SKIPPED … 480 min past target`.
- **Round 3:** R with `TZ` set uses its bundled tz database, while `env -u TZ /bin/date` uses the system one, and they disagree. On this Mac the system database puts America/Vancouver on UTC-7 (MST) for 2026-11-05, while a `TZ=America/Vancouver` Rscript gave UTC-8. That is why the zone tests use Asia/Tokyo, and why launchd's digits come from `/bin/date`.
- **Mutation testing:** every guard added on the branch went red with its defect planted in a scratch copy (progress.md lists each).
- **Review cost:** six reviewer agents (the Plan review plus five code-check rounds). The review ended by enumeration: round 5's 16 process and tool boundaries are each consistent, fixed or accepted. The JSON boundary is held by a test over every scheduled field and shape.

## Owed

- Close PR #46 as folded into this move's PR
- Next move: #43 (move 2 of 3)
- Draft (not post) a gargle upstream note about cache keys derived from `rlang::hash()`. It goes to the user for approval, per the "never post outside our repos" rule.

Closed by: the PR for branch `47-1-3-run-mc-unattended-r-cmd-check-in-ci`
