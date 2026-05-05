# Task: Auto-create missing Gmail labels for YAML-driven workflow (#33)

## Problem

`mc_thread_modify()` errors on unknown labels (`R/mc_thread_modify.R:146-152`). The YAML-driven label workflow added in #31 reads `labels:` from frontmatter and applies them via `mc_thread_modify()` — but only succeeds if the labels already exist in Gmail.

When a user adds a new project tag to a draft (e.g. `labels: [upper fraser]`) and that label doesn't yet exist, `mc_md_send()` creates the draft, then the labels block fails. Per the v0.2.8 try-catch we land a warning (good — the draft survives), but the user still has to drop down to `gmailr::gm_create_label()` manually, then re-apply with `mc_thread_modify()`. That's friction in the spot the YAML workflow was supposed to remove.

## Design

Three layered additions:

1. **`mc_label_ensure(names)`** — exported primitive (`R/mc_label_ensure.R`). Creates missing user labels, no-op for existing.
2. **`mc_thread_modify(..., create_missing = FALSE)`** — opt-in flag. When `TRUE`, calls `mc_label_ensure(add)` before `resolve_label_names()`. Default `FALSE` preserves typo-guard behavior.
3. **`mc_send(..., labels_create = TRUE)`** — default `TRUE` since YAML-tagging is the main use; programmatic callers can pass `FALSE`. `mc_md_send()` inherits via existing `override` mechanism.

Reuses internal helpers `fetch_user_labels()` and `system_labels()` from `R/mc_thread_modify.R`.

## Phase 1: `mc_label_ensure()` primitive + unit tests

- [x] Create `R/mc_label_ensure.R` — exported function, signature `mc_label_ensure(names)`, validates with `chk::chk_character()`, fetches existing user labels via `fetch_user_labels()`, computes missing (excluding system labels via `system_labels()`), iterates `gmailr::gm_create_label(nm)`, returns `invisible(names)`.
- [x] Roxygen: `@importFrom gmailr gm_create_label`, `@export`, `@examples \dontrun{...}`.
- [x] `tests/testthat/test-mc_label_ensure.R`:
  - rejects non-character input
  - no-op when all labels exist (mocked `gm_labels`, no `gm_create_label` calls)
  - creates only missing names (mocked, verify `gm_create_label` called with exactly the missing set)
  - skips system labels (e.g. `STARRED` not "created")
  - returns `invisible(names)`
  - no-ops on empty input without fetching labels
- [x] `devtools::document()`, `devtools::test()` (289 pass, 0 fail), `lintr::lint_package()` clean.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Phase 2: `create_missing` flag on `mc_thread_modify()`

- [x] Add `create_missing = FALSE` parameter to `mc_thread_modify()`. Validate with `chk::chk_flag()`.
- [x] When `create_missing = TRUE` and `add` is non-NULL, call `mc_label_ensure(add)` before `fetch_user_labels()` so freshly-created labels are visible to the resolver.
- [x] New tests in `test-mc_thread_modify.R`:
  - rejects bad `create_missing` (non-flag)
  - `create_missing = FALSE` (default) errors on unknown — back-compat preserved
  - `create_missing = TRUE` calls `mc_label_ensure(add)` and applies resolved IDs
  - `create_missing = TRUE` with `add = NULL` skips ensure
- [x] `devtools::document()`, `devtools::test()` (297 pass, 0 fail), `lintr::lint_package()` clean.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Phase 3: `labels_create` in `mc_send()` + integration test

- [x] Add `labels_create = TRUE` parameter to `mc_send()`. Validate with `chk::chk_flag()`.
- [x] Inside the labels try-catch, pass `create_missing = labels_create` to `mc_thread_modify()`.
- [x] Thread `labels_create` through the scheduled-send recursive call (callr `r_bg` args, inner function signature, recursive `mc::mc_send()` call).
- [x] Update existing labels mocks in `test-mc_send.R` to accept the new `create_missing` arg passed by `mc_send()`.
- [x] New unit tests in `test-mc_send.R`:
  - `labels_create = TRUE` (default) → `mc_thread_modify` called with `create_missing = TRUE`
  - `labels_create = FALSE` → `mc_thread_modify` called with `create_missing = FALSE`
  - rejects non-flag `labels_create`
- [x] New integration test in `test-integration.R` (gated by `MC_RUN_INTEGRATION=true`):
  - Generates unique fresh label name (`mc-fresh-label-<timestamp>`)
  - Asserts label does NOT exist pre-test
  - `mc_md_send()` a draft with that label in YAML
  - Verifies label exists post-test and is attached to the draft thread
  - Cleanup via `withr::defer()`: deletes the auto-created label
- [x] `devtools::document()`, `devtools::test()` (302 pass, 0 fail), `lintr::lint_package()` clean.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Phase 4: Docs polish + release prep

- [x] Update `@details` / `@param labels_create` for `mc_send()` (done inline in Phase 3).
- [x] Update `@details` / `@param create_missing` for `mc_thread_modify()` to cross-ref `mc_label_ensure()` (done inline in Phase 2).
- [x] Add `# mc 0.2.9` block at top of `NEWS.md` — bullets cover the new primitive, the `create_missing` flag, the `labels_create` default, and the case-insensitive system-label fix.
- [x] `DESCRIPTION` Version: `0.2.8` → `0.2.9`.
- [x] Full `devtools::document()`, `devtools::test()` (302 pass, 0 fail), `lintr::lint_package()` clean for changed files.
- [x] `/code-check` on staged diff.
- [x] Atomic commit including checkbox flips.

## Validation

- [ ] All existing tests still pass (≥281 PASS baseline from 0.2.8).
- [ ] New unit tests pass for `mc_label_ensure`, `mc_thread_modify(create_missing=)`, `mc_send(labels_create=)`.
- [ ] Integration test passes (or skips cleanly when `MC_RUN_INTEGRATION` unset).
- [ ] `lintr::lint_package()` clean.
- [ ] `/code-check` clean on each phase commit.
- [ ] Manual sanity check: `mc_md_send()` on fresh `.md` with new label name in YAML creates the label and tags the thread.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.
- [ ] `/gh-pr-merge` for NEWS finalization, tag, post-merge CI watch.
