# Code-check round 5 (#47, final): round-4 fixes, and the enumeration re-walked

Reviewed: `round4-fixes.diff`, then the current `R/mc_deliver.R`, `R/mc_schedule.R` and
`R/mc_auth_check.R`, with `branch.diff` for context. Probes ran in a copy of the package under
the session scratchpad (`r5/pkg`), with HOME set to a temp dir, Gmail calls mocked and the
scheduler backends mocked. No real launchd or at job was created and nothing was sent.
Tree measured at `10691d3`.

## Checklist read

- **code-check.md**: the prose of all 14 H3s under `## Mechanisms`. The most relevant to this
  round: A proxy is not the property; A guard that fails toward pass ("Defaults and
  normalisers"); A guard's scope, escape hatches, and remedies; Serialization loses meaning
  silently; Restore the bug and prove the guard fires. Not read: 23.
- **code-check-r.md**: Cross-function consistency for label/string normalization; Under
  `R CMD check`, tests run from a temp dir against the INSTALLED package; A `pkg::` call in a
  test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared; A
  `function(...)` mock hides arguments the real callee no longer accepts; `$` on a list
  partial-matches, so a longer sibling key answers for a missing one. Not read: 111.
- **code-check-shell.md**: Paths; Diagnose env/PATH problems in the shell that actually runs,
  not the ambient one. Not read: 68.
- **code-check-spatial.md**: none apply to this diff. Not read: 94.

## Round-4 fixes: checked one by one

- **send_log `%Z`**: correct. Nothing in `R/`, the tests, the README or the vignette parses
  `send_log.txt`. The only reader that existed before, the test "send_log writes to
  ~/.mc/send_log.txt", matches on substrings, so it is unaffected. Restoring the old format
  turns "send_log lines name their zone" red (mutation run in a copy).
- **`schedule_launchd()` builds the plist before writing the JSON**: correct. Probe: with
  `system_wall_clock()` mocked to `stop()`, the call errors with "clock" and the temp HOME holds
  0 files. (`schedule_at()` still writes the JSON before its `Rscript` check. That leaves at
  most an orphan file and is not a failure.)
- **Docs: run `Rscript -e 'mc::mc_auth_check()'`, keep the variables in `~/.Renviron`**:
  incomplete. See finding 2.
- **`normalizePath(attachments, mustWork = TRUE)`**: it does reach an absolute path. `~` is
  expanded and `/var` becomes `/private/var`, both harmless. But it also resolves symlinks and
  canonicalizes case, and gmailr names the attachment by `basename()` of the path. See finding 1.
  Restoring the old line turns "a scheduled send carries attachments as absolute paths" red.
- **Every other field of `schedule_args`**:
  - `to`, `subject`, `cc`, `bcc`, `thread_id`, `labels`, `labels_create`, `to_self`: values,
    not paths.
  - `from`: resolved by `default_from()` in the session and serialized.
  - `html`: rendered up front.
  - `sig` and `sig_path`: unused at fire time, because `html` is non-NULL there, so
    `mc_md_render()` is never called and a relative `sig_path` never resolves. Consistent.
  - The JSON round trip does change one type: see finding 3.

## Enumeration

Round 4's table, re-walked against the current code, plus the boundaries it missed.

| # | Boundary | Verdict |
|---|---|---|
| 1 | R → launchd `StartCalendarInterval` digits | **Consistent** (unchanged). Residuals accepted: fall-back hour, no Year key, a system-zone change. |
| 2 | R → launchd `ProgramArguments` | **Consistent.** Rscript and the args JSON path are absolute. |
| 3 | R → launchd job working directory (`/`) | **Fixed for attachments.** No other carried field resolves a relative path at fire time (`sig_path` is unused once `html` is set). The fix introduced finding 1. The same cwd also decides which `.Renviron` and `.Rprofile` the job reads: see row 14. |
| 4 | R → launchd job environment and library | **Environment fixed (documented).** **Library accepted** (renv / `R_LIBS`, stated in the PR). |
| 5 | R → `at` time | **Consistent.** Fall-back hour accepted. |
| 6 | R → `at` job context | **Consistent.** `at` keeps cwd, env and umask. |
| 7 | R → JSON → fire-time R | Instants, `from`, `html`: **consistent.** `attachments`: **fixed**, with finding 1. Zero-length vectors: **inconsistent, finding 3** (new row). |
| 8 | R → callr child | **Consistent.** RDS keeps types. The attachment normalization now applies here too, so finding 1 reaches callr as well. |
| 9 | Console message and SCHEDULED detail | **Consistent.** Session zone, `%Z` named. The comment at `mc_deliver.R:105-106` is now true. |
| 10 | SKIPPED messages | **Consistent.** Fire-time zone, `%Z` named. |
| 11 | send_log line timestamps | **Fixed.** `%Z`, no parsers, guard proven by mutation. |
| 12 | `mc_auth_check()` → the process that authenticates | **Fixed in docs, partly.** Running it from a fresh process matches launchd only when the cwd has no `.Renviron` or `.Rprofile` of its own: finding 2. |
| 13 | Fire-time gmailr account | **Accepted.** |
| 14 | Fire-time R startup files (new) | The launchd job runs in `/`, so it reads `~/.Renviron` and `~/.Rprofile`. An `Rscript` started in a project directory reads that project's `.Renviron` and `.Rprofile` first, and the `.Rprofile` may activate renv. **Inconsistent between the check and the job: finding 2.** For `at` the job keeps the cwd, so the check matches it when run from the scheduling directory. |
| 15 | Attachment contents (new) | **Consistent across backends.** All three read the file at fire time. A deleted file is logged FAILED. This behaviour predates the branch. |
| 16 | HOME in the plist XML and the R string (new) | Not escaped: a HOME containing `"`, `&` or `<` breaks the plist. **Predates the branch**, accepted as out of scope. |

So the review is **not converged**. Rows 3 and 8 carry a defect the round-4 fix introduced
(finding 1). Row 7 carries a type change that predates the branch but that the new default now
reaches (finding 3). Row 12/14 is the same context mechanism, one axis over, in the advice
itself (finding 2). Every other row is consistent, fixed or accepted.

## Findings

1. **[bug]** `R/mc_deliver.R:120-122`: `normalizePath()` changes the name the recipient sees on a
   scheduled send's attachment.
   - `normalizePath()` resolves symlinks and canonicalizes case on macOS.
   - `gmailr::gm_attach_file()` (3.0.0) sets both `name` and `filename` to `basename(filename)`,
     and guesses the MIME type from that name.
   - End-to-end probe in the copy. `report.pdf` is a symlink to `build/report_8f3a.pdf`:
     - Scheduled send, through `run_scheduled_send()` from `/`: the MIME carries
       `filename=report_8f3a.pdf`.
     - The same call sent immediately: `filename=report.pdf`.
   - Case: `attachments = "NOTES.TXT"` against `notes.txt` gives the basename `notes.txt`.
   - This applies to every backend, callr included, because the normalization sits before
     `schedule_send()`.
   - A target with no extension, such as a content-addressed blob, also changes the guessed
     MIME type.
   - Fix: make the path absolute without touching the basename:
     `file.path(normalizePath(dirname(attachments), mustWork = TRUE), basename(attachments))`.
     A symlink is then still followed at fire time, as it was before.
   - **Rule:** code-check.md, "A guard that fails toward pass" ("Defaults and normalisers": a
     normaliser hands the normalised form to every later consumer, so return the value as given
     wherever downstream stores or keys on it). Also code-check-r.md, "Cross-function
     consistency for label/string normalization" ("the canonical form is safe only where nothing
     downstream keys on or stores the returned value").

2. **[fragile]** `R/mc_auth_check.R:32-36`, `man/mc_auth_check.Rd`, README Troubleshooting block:
   the advice "run it from a fresh process" does not reproduce the launchd job's context when
   it is run from a project directory.
   - R reads `.Renviron` and `.Rprofile` from the cwd in preference to `~`.
   - Probe: a project `.Renviron` held `GMAILR_OAUTH_CLIENT=from_project` and `~/.Renviron`
     held `from_home`.
     - `Rscript` in the project printed "project Rprofile" and then `from_project`.
     - The same `Rscript` from `/`, which is where the launchd job runs, printed `from_home`.
   - So the check can pass against a project's OAuth client, or against the rlang in a
     renv library its `.Rprofile` activates (the motivating rlang-upgrade case). Meanwhile the
     launchd job, reading `~` and the user library, fails with "Can't get Google credentials".
   - The remedy is the code a user will run, and as written it checks the wrong process.
   - Fix (docs only): for launchd, run `cd ~ && Rscript -e 'mc::mc_auth_check()'`, and say
     that a project's own `.Renviron` or `.Rprofile` is not what a launchd job reads.
   - **Rule:** code-check.md, "A guard's scope, escape hatches, and remedies" (a remedy is code
     the caller will run, and nothing checks it). Also code-check-shell.md, "Diagnose env/PATH
     problems in the shell that actually runs, not the ambient one".

3. **[bug]** `R/mc_schedule.R:457-461` with `:330`: a zero-length `cc`, `bcc`, `labels` or
   `attachments` fails a scheduled send at fire time.
   - `write_json()` writes `character(0)` as `[]`, and `read_json(simplifyVector = TRUE)` reads
     it back as `list()`. `mc_deliver()`'s `chk_null_or(..., vld_character)` then refuses it.
   - End-to-end probe in the copy, through `run_scheduled_send()`:
     - `cc = character(0)` → `STARTED / FAILED`, "`cc` must be character or NULL".
     - `labels` and `attachments` fail the same way.
     - The same calls sent immediately succeed.
   - A filter that matches no rows produces exactly this value (`cc = contacts$email[cond]`),
     and nothing is sent.
   - The JSON path predates the branch. But under the old callr default, RDS kept the type, and
     this branch makes launchd / at the default on macOS and Linux. So it is new for every user
     who did not name a scheduler: the same shape as round 4's finding 1.
   - Fix: in `write_scheduled_args()`, `args <- lapply(args, function(v) if (length(v) == 0)
     NULL else v)` (zero-length means "none" for every field that can be empty). Or coerce
     `list()` to `NULL` after `read_json()`.
   - **Rule:** code-check.md, "Serialization loses meaning silently". Also code-check.md,
     "Zero-length, empty, and unset are three different things".

## Verdict

Not clean, and not converged: two bugs (finding 1, introduced by the round-4 fix; finding 3, a
JSON type change the new default exposes) and one fragile documentation remedy (finding 2).
The other round-4 fixes (`%Z`, plist-before-JSON) are correct and proven by mutation or probe.
All other enumerated boundaries are consistent, fixed or accepted.
