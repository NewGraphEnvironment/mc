# 2026-04 — Issue #28: mc_thread_modify()

Shipped `mc_thread_modify(thread_id, add, remove)` — single verb for
modifying a Gmail thread's label state. Covers archive, trash, star,
mark-read, and user-label workflows. Accepts names (system or user
labels); resolves user names to opaque Gmail IDs via `gm_labels()`.

During integration testing, discovered that `gmailr::gm_modify_thread()`
in 3.0.0 is completely broken — calls `rename(list(...))` instead of
`rename(...)`, producing malformed JSON that Gmail rejects with HTTP
400. Filed root-cause analysis on the 2-year-old upstream issue
(r-lib/gmailr#150). Workaround in mc: POST directly to
`users.threads.modify` via httr. `httr` added to Imports.

Tests: 23 unit tests (mocked gmailr) + 2 integration tests (real Gmail
round-trip). Full suite: 262 PASS, 0 FAIL, 1 SKIP.

Closed by PR #30 (merge commit 373b4a6). Released as v0.2.7.
