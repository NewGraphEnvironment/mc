# Code-check round 1: branch 47-1-3-run-mc-unattended-r-cmd-check-in-ci (667d30b...HEAD)

## Checklist read

- **code-check.md:** read all 14 `## Mechanisms` H3 sections (prose only, `|` rows skipped): A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice. Did not read the other 23 headings (only their index lines).
- **code-check-r.md:** read Cross-function consistency for label/string normalization; `$` on a list partial-matches, so a longer sibling key answers for a missing one; A `function(...)` mock hides arguments the real callee no longer accepts; Never name a durable artifact by a hash the library reserves the right to change; `system2(stdout = TRUE)` warns on a non-zero exit instead of raising...; `nzchar(NA)` is TRUE. That is 6 read; 110 not read beyond the index.
- **code-check-shell.md:** read none in full (index only); 70 not read. The diff has no shell code beyond a workflow `uses:` line.
- **code-check-spatial.md:** read none in full (index only); 94 not read. Nothing spatial in the diff.

## What I ran (all in a temp copy, `.../scratchpad/mcQFY3/mc`, with no OAuth client and an empty gargle cache)

- `testthat::test_file()` on the five changed test files: auth_check 12, schedule 19, send 30, draft 10, thread_modify 16. All passed with 0 failed and 0 errors. Afterwards, `~/.mc/scheduled` did not exist, `launchctl list` held no `newgraph.mc` job, and no callr processes were running.
- I built a real `gargle::Gargle2.0` R6 token (fake access token, `cache_path = FALSE`), saved it under its own `$hash()` and ran `mc_auth_check()` on it. It passed when the names matched and reported a mismatch when they did not, so the list fixtures in the tests act like real tokens.

## Findings

- **[severity: bug]** R/mc_auth_check.R:161-162: the email filter checks only the end of the filename, so a different account's token can make the check pass.
  - The code uses `files[endsWith(files, paste0("_", email))]`. gargle's own pattern is `^([0-9a-f]+)_(.*?)$`: the hash is hex, so the email is everything after the first `_`.
  - A token for `sales_al@example.com` (file `<hash>_sales_al@example.com`) therefore counts as a token for `al@example.com`.
  - gargle's `token_match()` needs the whole `<hash>_<email>` to match when a non-wildcard email is given, so it would not find a token for al.
  - Reproduced: with only `abc123_sales_al@example.com` in the cache (same client id, matching name), `mc_auth_check("al@example.com")` prints "matches" and returns `TRUE`. The function then reports that unattended auth will work when it will fail with "Can't get Google credentials", which is the failure it exists to predict.
  - The test "ignores tokens cached for other emails" uses `xal@example.com`, which has no underscore before `al`, so it cannot catch this.
  - Fix: compare the email exactly, e.g. `files[sub("^[0-9a-f]+_", "", files) == email]`.
  - **Rule:** code-check.md "A proxy is not the property" ; code-check.md "A fixture that cannot reach the failure mode"

- **[severity: fragile]** R/mc_deliver.R:36-41 and R/mc_schedule.R:371-373 (the new `default_scheduler()`): on macOS the default scheduled send loses its stale-send guard. A send can now go out hours late.
  - Before this branch the default was callr, with two protections:
    - `caffeinate -i -w` keeps the machine awake.
    - The child skips the send if it wakes more than 300 s past the target (`grace_secs = 300`, R/mc_schedule.R:84-93; logs SKIPPED).
  - The new default on macOS is launchd, which has neither:
    - `man launchd.plist`: "Unlike cron which skips job invocations when the computer is asleep, launchd will start the job the next time the computer wakes up."
    - `run_scheduled_send()` has no lateness check, and the args JSON does not carry the target time, so it could not check.
  - So a laptop that sleeps through a 9:00 send now sends when it next wakes, with no limit on how late. The old default would have kept it awake, or skipped and logged it.
  - The vignette's sentence about the 5-minute grace period was deleted rather than replaced, and README:183-186 says the grace is "callr backend only". So the docs now say the default has no protection, but nothing warns the user who relied on it.
  - Either carry the target time and grace into `run_scheduled_send()` (skip and log SKIPPED when late, as callr does), or accept this deliberately and say so where the default is described.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness"

- **[severity: fragile]** R/mc_schedule.R:232-241 and 256-266: on Linux the default now goes to `at`, which can drop a send silently when `atd` is not running.
  - The new `Sys.which("at")` check covers a missing binary. It does not cover the case the function's own header comment names: "If `atd` is stopped, `at` will accept and queue the job but it will never fire — a silent failure mode".
  - `system2(..., stdout = TRUE, stderr = TRUE)` captures `at`'s output, but the code reads only the exit status and a `^job N` line. Any warning `at` prints about atd is thrown away.
  - Before this branch, Linux users got callr by default along with a `warning()` that the send could be dropped. Now the default path has a silent drop mode and no warning.
  - Untested here (macOS host). I am relying on the comment's own claim about `at`'s exit status when atd is down.
  - **Rule:** code-check.md "A wrapper's exit is not the work"

Nothing else found. The `toupper()` system-label check in mc_thread_modify.R now matches `resolve_label_names()` and `mc_label_ensure()`. Moving the "Provide either" check ahead of the `chk_string(from)` call forces no promise early. `auth_client()` follows the client resolution in `gm_auth()` and `gm_auth_configure()` (gmailr 3.0.0), and `auth_cache_dir()` follows `cache_establish()` (gargle 1.6.1).
