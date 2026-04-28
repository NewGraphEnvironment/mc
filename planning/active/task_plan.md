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

- [x] Add `labels = NULL` arg to `mc_send()`
- [x] Validate: `chk::chk_null_or(labels, vld = chk::vld_character)`
- [x] After successful `gm_send_message()`: call `mc_thread_modify(thread_id, add = labels)`
- [x] After successful `gm_create_draft()` with non-null labels: emit warning ("Labels not applied to drafts. Re-apply after sending with `mc_thread_modify()`."), skip apply
- [x] Thread `labels` through scheduled-send (`send_at`) recursive call
- [x] Roxygen: document `labels` param + draft-path tradeoff
- [x] Commit

## Phase 4: YAML labels: in mc_md_send

- [x] `mc_md_send()` reads `meta$labels` and passes to `mc_send(labels = ...)`
- [x] Update `mc_md_send` roxygen to list `labels` as a recognized frontmatter field
- [x] Test: labels: array in YAML reaches mc_send
- [x] Test: NULL labels when frontmatter omits the field
- [x] Commit

## Phase 5: tests, docs, NEWS, version bump

- [x] Unit tests in `test-mc_send.R`:
  - [x] mc_send returns thread_id from draft path
  - [x] mc_send returns thread_id from sent path
  - [x] mc_send with labels on draft path applies labels (changed from warn+skip per user feedback)
  - [x] mc_send with labels on sent path calls mc_thread_modify with correct args (mock)
  - [x] mc_send labels arg validation (non-character errors)
  - [x] mc_send warns rather than errors when label apply fails (post code-check round 2)
- [x] Unit tests in `test-mc_md_send.R`:
  - [x] labels: from YAML passed through to mc_send call
  - [x] empty `labels: []` and `labels: ~` coerce to NULL (post code-check round 2)
- [x] Integration tests (skip on CI, real Gmail):
  - [x] sent path applies a throwaway label and verifies it lands on the thread
  - [x] draft path with labels: applies to draft thread
  - [x] mc_md_send YAML labels apply end-to-end
- [x] NEWS.md entry under new 0.2.8 heading
- [x] DESCRIPTION: bump Version to 0.2.8
- [x] `devtools::document()` — regenerate man pages + NAMESPACE
- [x] `devtools::test()` — 281 pass, 0 fail, 1 skip (integration)
- [x] Commit

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
