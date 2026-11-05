# Progress — [3/3] Drafts and search (#51)

## Session 2026-11-05

- Plan-mode exploration — phases approved by user (gate: list return, `draft_id` argument, frontmatter write-back, warn-and-create on a stale id)
- Created branch `51-3-3-drafts-and-search-return-and-replace` off origin/main
- Scaffolded PWF baseline from issue #51 with approved phases
- Next: start Phase 1
- Phase 1 (#49, #50): `mc_thread_read()` classifies by each message's `DRAFT` label and drops drafts when `drafts = FALSE`; `fetch_thread_drafts()` removed. `mc_message_find()` runs one Gmail search per call (`in:drafts` / `-in:drafts` / bare), status from labels. New tests were red on main (double row, ignored query) and green after. 615 pass; lints unchanged except thread_read tests 5 → 3.
