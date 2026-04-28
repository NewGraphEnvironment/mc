# 2026-04 — Issue #31: YAML-driven Gmail labels

Shipped a `labels` argument on `mc_send()` that applies Gmail labels via
`mc_thread_modify()` after creating a draft or sending. `mc_md_send()`
reads `labels:` from YAML frontmatter, so project tags can live alongside
`to`, `subject`, `cc`, etc. in the `.md` draft. `mc_send()` now returns
the gmailr-assigned threadId invisibly (was `invisible(NULL)`) so callers
can chain follow-on operations cleanly.

Drafts get labelled too — applied to the draft thread so it's findable in
Drafts under the project label, and Gmail typically keeps the same
thread when sent from the UI so labels carry over. If they don't,
`mc_thread_modify()` re-applies in one line.

Code-check (3 rounds) flagged 4 real issues in round 2, all fixed before
PR open: (1) wrap `mc_thread_modify` in tryCatch so label failures
downgrade to a warning rather than cascading after a successful send;
(2) coerce empty YAML labels (`labels: []`, `labels: ~`) to NULL in
`mc_md_send` so chk accepts them as no-op; (3) distinguish "draft thread"
vs "thread" in the labels-applied message so users with draft + thread_id
understand labels attach to the orphan draft thread; (4) thread `labels`
through scheduled-send recursive call.

Tests: 6 new unit tests + 3 new integration tests (real Gmail round-trip
covering sent path, draft path, and YAML-driven label end-to-end). Full
suite: 281 PASS, 0 FAIL, 1 SKIP.

This PR also un-gitignored `planning/active/` so atomic commits can
bundle code changes with `task_plan.md` checkbox updates per soul PWF
convention. Going forward the planning files are tracked.

Closed by PR #32 (merge commit e8bfdd5). Released as v0.2.8.
