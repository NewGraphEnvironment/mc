# Task: [1/3] Run mc unattended: R CMD check in CI, send_at scheduler default, auth preflight (#47)

The first R-CMD-check run on #46 (ubuntu-latest) has test ERRORs from tests that need a configured sender or Gmail credentials, which a runner does not have, and two WARNINGs. This move also carries #8 (default `scheduler` becomes OS-native) and #38 (`mc_auth_check()` preflight and troubleshooting). Each is mc running from `Rscript`, cron or CI rather than an interactive session.

Plan approved by the user 2026-11-04 (plan mode, `/planning-init 47`).

## What exploration found (shaped the phases)

- **Two of the three test ERRORs are lookup order, not missing credentials.** In `R/mc_deliver.R:45`, `chk_string(from)` forces `default_from()` before the "Provide either `path`…or `html`" check at line 74. With no sender set, it fails on the sender first. The tests pass locally only because a sender is configured here.
- **The third ERROR is a real bug, not missing credentials.**
  - `mc_thread_modify()` at `R/mc_thread_modify.R:67` decides whether to fetch user labels with a case-sensitive `all_names %in% system_labels()`.
  - `resolve_label_names()` at line 152 matches with `toupper()`, so it is case-insensitive.
  - So `add = "Starred"` calls `gm_labels()` for nothing. That call needs auth, which is why it failed on CI.
  - The test at `test-mc_thread_modify.R:250` exists for this case. It only passes here because this machine has a token.
  - This is `code-check-r.md`'s "cross-function consistency" trap. Skipping the test when no credentials exist (the issue's proposal 2) would have hidden it.
- **Non-ASCII:** the WARNING counts string literals, not comments. There are 6 em dashes in strings:
  - `mc_deliver.R:90`, `mc_deliver.R:237`
  - `mc_draft.R:60`
  - `mc_md_draft.R:82`
  - `mc_schedule.R:134`, `mc_schedule.R:228`

  Dashes in comments and roxygen are allowed, so they stay.
- **Undocumented `...`:** `mc_draft()` has `...` with no `@param`.
- **Two NOTEs (not gating, since flows errors on warnings):**
  - `.lintr` and `.claude` ride into the tarball. Fixed with `.Rbuildignore`.
  - The `mc:::send_log` / `send_notify` calls in `mc_schedule.R:78-94` sit inside the `callr::r_bg` closure, which runs in a child process, so `:::` is correct there. Left as is.
- **Scheduler:**
  - `mc_send()` and `mc_deliver()` take `scheduler = c("callr", "auto", "launchd", "at")` and pick it with `match.arg`.
  - `resolve_scheduler()` (`mc_schedule.R:34`) errors on `"auto"` outside Darwin and Linux.
  - `mc_md_send()` only forwards `scheduler` when an override supplies it, so a new default reaches it automatically.
  - Two tests in `test-mc_send.R` (`:363`, `:385`) rely on the callr default and need `scheduler = "callr"` written in.
- **Auth:**
  - gargle 1.6.1 / gmailr 3.0.0 / rlang 1.3.0 are installed.
  - `gmailr::gm_oauth_client()` returns the configured client, whose `$name` is the computed name. `gmailr::gm_default_oauth_client()` gives the JSON path, and `gargle::gargle_oauth_client_from_json(path)$name` computes the name from it.
  - Cached tokens live in `gargle::gargle_oauth_cache()` as `<hash>_<email>` files.
  - gargle is already a hard dependency of gmailr, so adding it to Imports installs nothing new.
  - `_pkgdown.yml` has no reference index, so a new export needs no pkgdown edit.
- **PR #46:**
  - Branch `ci-r-cmd-check` is behind main, and its only change against main is `.github/workflows/R-CMD-check.yaml`, which calls `flows/r-cmd-check.yaml@v1`.
  - #47's body offers two routes, and I take the second: merge that branch into this one and close #46 as folded in. That keeps the branch cut from `origin/main` as the skill does it.
- **Issue comments:** none on #47, #8, #38 or PR #46. #8's decision is in its body and is followed here.

## Decided at the gate

- **Sender ordering:** fixed in two places. The path/html check moves ahead of the sender lookup, because an argument error should come before an environment error. The tests also unset the sender themselves, so they reproduce the CI condition on any machine.
- **#47 proposal 2 (skip tests that need credentials):** declined. After the fix above, no unit test needs credentials. The one that seemed to was the case bug.
- **WARNINGs are cleared, not suppressed.** No `error-on: "error"` override.
- **`scheduler` default becomes `NULL`**, the form a wrapper can pass, unlike `missing()`. `NULL` resolves to `"auto"` on Darwin and Linux and to `"callr"` elsewhere, with callr's existing warning. An explicit `"auto"` still errors on unsupported platforms, and invalid values still give match.arg's "should be one of".
- **New export `mc_auth_check(email = default_from())`:**
  - Compares each cached token's stored client name for `email` with the name the session computes.
  - Returns `invisible(TRUE)` when they match.
  - With no token for that email, or no matching name, it aborts. The message names both client names and the fix: restart R, move the stale token aside, run `mc_auth()`.
- **Version:** minor bump to 0.4.0 plus a NEWS entry, both written by `/gh-pr-merge` at merge.

## Phase 1: Fold in the CI workflow

- [x] `git merge origin/ci-r-cmd-check` into the move branch, bringing in `.github/workflows/R-CMD-check.yaml`
- [x] Add `^\.lintr$` and `^\.claude$` to `.Rbuildignore`

## Phase 2: Tests run without a sender or credentials (#47)

- [x] Failing tests first:
  - `test-mc_draft.R:5` and `test-mc_send.R:1` unset the sender with `withr::local_options(mc.from = NULL)` and `withr::local_envvar(MC_FROM = NA)`. Both should then fail on "No default email found".
  - `test-mc_thread_modify.R:250` gets a `gm_labels` mock that `stop()`s ("system labels must not fetch user labels"). It should fail on the case bug.
- [x] `mc_deliver()`: move the `is.null(path) && is.null(html)` stop ahead of the `chk` block, so it runs before `from` is forced
- [x] `mc_thread_modify()`: `toupper(all_names) %in% system_labels()`, which matches `resolve_label_names()`
- [x] Restore each bug and confirm its test goes red, then green with the fix

## Phase 3: Clear the check WARNINGs (#47)

- [ ] Replace the 6 em dashes in string literals with ASCII ` - `, then grep the tests for any message they match on
- [ ] Add `@param ...` to `mc_draft()` saying it is not used, and that `send_at` / `scheduler` error toward `mc_send()`
- [ ] `devtools::document()`. Then `tools:::.check_package_ASCII_code(".")` returns nothing, and `mc_draft.Rd` documents `...`

## Phase 4: OS-native scheduler by default (#8)

- [ ] Failing tests first, in `test-mc_schedule.R`, mocking `Sys.info` and `schedule_send`:
  - with no scheduler named, Darwin passes `"auto"`, which resolves to launchd, and Linux resolves to at
  - Windows uses `"callr"` and gives the callr warning
  - an explicit `"auto"` on Windows still errors
- [ ] Add internal `default_scheduler()` in `mc_schedule.R`, plus the `NULL` default in `mc_send()` and `mc_deliver()`, with `match.arg(scheduler, choices)` when the scheduler is not `NULL`
- [ ] Update `test-mc_send.R:363` and `:385` to pass `scheduler = "callr"` explicitly
- [ ] Update the `mc_send()` `@param scheduler` text, the README "Scheduled send" section, and the CLAUDE.md lines above the marker (Key Patterns scheduler line; Known Issues #8)

## Phase 5: Auth preflight and troubleshooting (#38)

- [ ] Failing tests first, in `test-mc_auth_check.R`, against a temp cache dir holding fake token RDS files (`list(app = list(appname = ...))`) and a mocked client name:
  - matching name → `TRUE`
  - mismatched name → error naming both names and `mc_auth()`
  - no token for the email → error
- [ ] Write `R/mc_auth_check.R`:
  - The expected name comes from `gmailr::gm_oauth_client()$name`, or else from `gargle::gargle_oauth_client_from_json(gmailr::gm_default_oauth_client())$name`.
  - The stored name comes from `tok$app$appname`, falling back to `tok$app$name`.
  - It reads token files with `readRDS` from `gargle::gargle_oauth_cache()`.
  - Arguments are checked with `chk`.
  - The roxygen includes `@section Troubleshooting` (upgrading rlang invalidates the gargle token cache; re-auth from a freshly started session) and a `\dontrun{}` example, since it needs real credentials.
- [ ] Add `gargle` to Imports
- [ ] README: a short "Troubleshooting" section before License, pointing to `mc_auth_check()`

## Owed at the end (reported, done after merge)

- [ ] Close PR #46 as folded into this move's PR
- [ ] Next move: #43 (move 2 of 3)
- [ ] Draft (not post) a gargle upstream note about cache keys derived from `rlang::hash()`. It goes to the user for approval, per the "never post outside our repos" rule.

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

How each change is proved:

- Each Phase 2/4/5 fix has a test that went red with the bug restored and green with the fix.
- A local run with no sender and no credentials gives `FAIL 0`: `env -u MC_FROM -u GMAILR_OAUTH_CLIENT R_PROFILE_USER=/dev/null Rscript -e 'devtools::test()'`
- `devtools::document()`, `lintr::lint_package()` and `rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "warning")` show 0 errors and 0 warnings locally.
- The R-CMD-check run on this PR passes on `ubuntu-24.04`. That run is the acceptance test #46 never had.
- Integration tests (`MC_RUN_INTEGRATION=true`) run once before merge, with the real-send BCC rule.

