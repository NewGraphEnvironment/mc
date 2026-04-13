# Task Plan — issues #17–#20

Adds thread/message search ergonomics and local preview to mc.

## Phase 1: Setup
- [x] Branch `thread-search-preview` created
- [x] PWF scaffolded in `planning/active/`

## Phase 2: #18 — date filters on mc_thread_find()
- [x] Add `after`/`before` args (Date or "YYYY-MM-DD")
- [x] Translate to Gmail `after:YYYY/MM/DD` / `before:YYYY/MM/DD`
- [x] Input validation via chk
- [x] Roxygen update with example
- [x] Tests (mocked gm_messages)
- [x] devtools::document() + test + lint
- [x] Commit: `Fixes #18` (693fb57)

## Phase 3: #19 — mc_message_find()
- [x] New file `R/mc_message_find.R`
- [x] Args: `query`, `n`, `after`, `before`, `status = c("any","sent","draft")`
- [x] Returns df: message_id, thread_id, from, to, subject, date, status
- [x] Reuse date-translation helper with #18
- [x] Tests (mocked)
- [x] Roxygen + example
- [x] Commit: `Fixes #19` (e4c52fc)

## Phase 4: #17 — mc_thread_body_latest()
- [x] New function in `R/mc_thread_find.R` (same file — thread helpers)
- [x] Args: `thread_id`, `strip_quotes = TRUE`, `status = c("any","sent","draft")`
- [x] Strip lines starting with `^>` and common "On … wrote:" attribution lines
- [x] Tests (mocked gm_thread)
- [x] Roxygen + example
- [x] Commit: `Fixes #17` (6cd7140)

## Phase 5: #20 — mc_preview()
- [x] New file `R/mc_preview.R`
- [x] Args: `html`, `open = interactive()`
- [x] Write to tempfile .html, `utils::browseURL()` when open
- [x] Return path invisibly
- [x] Tests (mocked browseURL)
- [x] Roxygen + example
- [x] Commit: `Fixes #20` (1ad05ea)

## Phase 6: PR
- [x] devtools::document(), test (173 pass, 1 skip), lint (no new) — green
- [x] Push branch, open PR with SRED tag in description — PR #21
- [ ] Archive PWF on merge
