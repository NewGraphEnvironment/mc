# Task Plan — mc_thread_modify() (issue #28)

## Phase 1: Research
- [x] Verify `gmailr::gm_modify_thread()` signature
- [x] Inspect `gm_labels()` return shape (system vs user label distinction)
- [x] Decide precedence when a user label name collides with a system label

## Phase 2: Source
- [x] Write `R/mc_thread_modify.R`
- [x] `devtools::document()` to update NAMESPACE / man
- [x] Workaround for gmailr 3.0.0 body-encoding bug (direct httr POST)

## Phase 3: Unit tests
- [x] Write `tests/testthat/test-mc_thread_modify.R` — 23 tests PASS
  - Input validation (reject non-string / non-character)
  - Error when both add and remove are NULL
  - System label passthrough without calling `gm_labels`
  - User label name → ID resolution
  - Add-only / remove-only / both in one call
  - Mixed system + user labels
  - Unknown label error with available-labels hint
  - `(none)` hint when user has no labels
  - System wins on name collision

## Phase 4: Integration test
- [x] Append to `tests/testthat/test-integration.R` — 12/12 PASS
  - Create throwaway label, apply + remove via mc_thread_modify
  - System label passthrough: star + unstar
  - `withr::defer` cleanup deletes the test label

## Phase 5: Docs & release
- [x] `NEWS.md` entry for v0.2.7
- [x] `DESCRIPTION` version bump to 0.2.7
- [x] `DESCRIPTION` adds httr to Imports
- [x] `lintr::lint_package()` clean on new files (pre-existing lints in `data-raw/`)
- [x] `devtools::test()` green — 262 PASS / 0 FAIL / 1 SKIP
- [x] `devtools::check()` — pre-existing WARNING/ERROR unrelated to this work
- [ ] Commit on `mc_thread_modify` branch
- [ ] File upstream gmailr bug issue
- [ ] Push and open PR (`Fixes #28`, `Relates to sred-2025-2026#1`)
