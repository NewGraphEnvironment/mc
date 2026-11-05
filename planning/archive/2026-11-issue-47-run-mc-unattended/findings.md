# Findings — [1/3] Run mc unattended (#47)

## Issue context

## Move 1 of 3: run mc unattended

This issue carries a batch. One `/planning-init 47`, one branch, one pull request, which closes all of these:

- [ ] #47 (this issue): R CMD check passes on a runner. Tests no longer need a sender or Gmail credentials, and the two WARNINGs are cleared. Detail below.
- [ ] #8: a scheduled send that names no `scheduler` uses the OS-native backend. The default becomes `"auto"`; where no OS-native scheduler exists (anything but macOS and Linux) the *default* falls back to `"callr"` with its existing warning, while an explicit `scheduler = "auto"` keeps its error. Behaviour change, so a minor version bump and a NEWS line. Decision recorded in #8.
- [ ] #38: a troubleshooting section (upgrading rlang invalidates the gargle token cache; re-auth from a freshly started session) and an `mc_auth_check()` preflight that compares the cached client name with the computed one and fails with an actionable message.

What ties them together: each is mc running from `Rscript`, cron or CI rather than an interactive session.

**Start from** PR #46's branch (`ci-r-cmd-check`), which holds the workflow. Either keep working on it, so #46 becomes this move's pull request, or merge that branch into the move's branch and close #46 as folded in. The pull request body carries `Fixes #47`, `Fixes #8`, `Fixes #38`.

**After merge, next move:** #43 (move 2 of 3).

---

**If we do it:** the R-CMD-check workflow in #46 can merge, and mc's check runs on every pull request. **If we never do:** #46 stays open and mc has no CI.

## Problem

The first R-CMD-check run on #46 (ubuntu-latest) has test ERRORs from tests that need a configured sender or Gmail credentials, which a runner does not have, and two WARNINGs.

**ERRORs**

- `test-mc_draft.R:6` and `test-mc_send.R:2` expect a "path or html" error, but `mc_draft()`/`mc_send()` first stop with *No default email found. Set options(mc.from = ...) or set the MC_FROM environment variable.* So the argument check runs after the sender lookup, or the tests depend on a sender being configured.
- `test-mc_thread_modify.R:258` reaches `gm_auth()`: *Can't get Google credentials. No OAuth client has been configured.*

**WARNINGs** (they predate the workflow)

- non-ASCII characters in `R/mc_deliver.R`, `R/mc_draft.R`, `R/mc_md_draft.R`, `R/mc_schedule.R`
- undocumented `...` in `mc_draft.Rd`

## Proposed Solution

1. Make the argument-validation tests independent of a sender: set `MC_FROM` in the test (`withr::local_envvar()`), or validate arguments before looking up the sender.
2. Skip tests that need Gmail credentials when none are configured.
3. Clear the WARNINGs, or add `error-on: '"error"'` with a comment pointing here, then merge #46.

Relates to #46



## Errors Encountered

| Error | Resolution |
|-------|------------|
| A shared workflow helper script fails to parse under macOS `/bin/bash` 3.2 (`syntax error near unexpected token ;;`) | Ran the workflow's shell steps under Homebrew bash 5; reported to the tooling's maintainers |
| The issue-comments helper was missing from the installed workflow tooling | Read comments with `gh api repos/.../issues/N/comments` |
