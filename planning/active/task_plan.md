# Task Plan — mc#31 YAML-driven Gmail labels

Issue: https://github.com/NewGraphEnvironment/mc/issues/31

## Phase 1: PWF baseline

- [ ] Read mc_send / mc_md_send / mc_thread_modify / mc_md_meta source thoroughly
- [ ] Write task_plan.md, findings.md, progress.md
- [ ] Commit PWF baseline

## Phase 2: mc_send returns thread_id

- [x] Capture `$threadId` from `gm_create_draft()` return value
- [x] Capture `$threadId` from `gm_send_message()` return value
- [x] Return invisibly from `mc_send()` (was `invisible(NULL)`)
- [x] Update existing test mocks to return objects with `$threadId` so non-NULL return assertions pass
- [x] Roxygen: update `@return` section
- [x] Run `devtools::test()` — confirm all existing tests still pass
- [x] Commit

## Phase 3: labels arg in mc_send

- [ ] Add `labels = NULL` arg to `mc_send()`
- [ ] Validate: `chk::chk_null_or(labels, vld = chk::vld_character)`
- [ ] After successful `gm_send_message()`: call `mc_thread_modify(thread_id, add = labels)`
- [ ] After successful `gm_create_draft()` with non-null labels: emit warning ("Labels not applied to drafts. Re-apply after sending with `mc_thread_modify()`."), skip apply
- [ ] Roxygen: document `labels` param + draft-path tradeoff
- [ ] Commit

## Phase 4: YAML labels: in mc_md_send

- [ ] `mc_md_send()` reads `meta$labels` and passes to `mc_send(labels = ...)`
- [ ] Update `mc_md_send` roxygen to list `labels` as a recognized frontmatter field
- [ ] Update `mc_md_meta` roxygen if it enumerates fields
- [ ] Commit

## Phase 5: tests, docs, NEWS, version bump

- [ ] Unit tests in `test-mc_send.R`:
  - [ ] mc_send returns thread_id from draft path
  - [ ] mc_send returns thread_id from sent path
  - [ ] mc_send with labels on draft path emits warning + skips
  - [ ] mc_send with labels on sent path calls mc_thread_modify with correct args (mock)
  - [ ] mc_send labels arg validation (non-character errors)
- [ ] Unit tests in `test-mc_md_send.R`:
  - [ ] labels: from YAML passed through to mc_send call
- [ ] Integration tests (skip on CI, real Gmail):
  - [ ] sent path applies a throwaway label and verifies it lands on the thread
  - [ ] draft path with labels emits warning and creates draft without label
- [ ] NEWS.md entry under new 0.2.8 heading
- [ ] DESCRIPTION: bump Version to 0.2.8
- [ ] `devtools::document()` — regenerate man pages + NAMESPACE
- [ ] `devtools::check()` — clean
- [ ] `lintr::lint_package()` — clean (or accept known issues)
- [ ] Commit

## Phase 6: code-check, PR, archive

- [ ] Run `/code-check` (3 rounds, fix real findings)
- [ ] Final atomic commit with PWF checkbox updates
- [ ] Push branch
- [ ] Open PR — body references mc#31, lists deferred items
- [ ] Merge after green
- [ ] Archive `planning/active/` → `planning/archive/2026-04-issue-31-yaml-labels/` with README
- [ ] Close mc#31 via Fixes in commit message

## Deferred (follow-up issues if needed)

- `labels_create = TRUE` opt-in auto-create + `mc_create_label()` public helper
- Pending-labels queue for drafts (`~/.mc/pending_labels.json` + `mc_labels_apply_pending()`)
- Hierarchical label helpers
