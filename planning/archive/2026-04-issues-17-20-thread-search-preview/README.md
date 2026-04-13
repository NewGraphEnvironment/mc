# Issues #17–#20 — thread-search-preview

Added four Gmail/compose ergonomics functions: `after`/`before` date filters on
`mc_thread_find()`, new `mc_message_find()` (message-level search), new
`mc_thread_body_latest()` (latest reply with quoted history stripped), and new
`mc_preview()` (local HTML preview before send). Two rounds of `/code-check`
surfaced operator-precedence in `strip_quoted()`, dead `tryCatch` in
`add_date_filters()`, duplicate drafts in `mc_message_find(status="any")`, and
lexical date sorting — all fixed before merge.

Closed via PR #21 (squash-merged as c1c90db). Released in v0.2.2.
