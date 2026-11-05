# Progress — [3/3] Drafts and search (#51)

## Session 2026-11-05

- Plan-mode exploration — phases approved by user (gate: list return, `draft_id` argument, frontmatter write-back, warn-and-create on a stale id)
- Created branch `51-3-3-drafts-and-search-return-and-replace` off origin/main
- Scaffolded PWF baseline from issue #51 with approved phases
- Next: start Phase 1
- Phase 1 (#49, #50): `mc_thread_read()` classifies by each message's `DRAFT` label and drops drafts when `drafts = FALSE`; `fetch_thread_drafts()` removed. `mc_message_find()` runs one Gmail search per call (`in:drafts` / `-in:drafts` / bare), status from labels. New tests were red on main (double row, ignored query) and green after. 615 pass; lints unchanged except thread_read tests 5 → 3.
- Phase 2 (#51): `mc_draft()`/`mc_md_draft()` return `list(draft_id, thread_id, message_id)`; `draft_id =` replaces through `PUT drafts/{id}` (`gmail_draft_request()`, `httr::stop_for_status()` like `gmail_modify_thread()` rather than gargle); a 404 raises `mc_draft_not_found`, which `write_draft()` turns into a warning and a fresh `gm_create_draft()`; any other error propagates (mutation: catching all errors turns that test red). `base64url_padded()` is byte-identical to gmailr's send encoding. `frontmatter_set()` records `draft_id:` byte-for-byte (CRLF kept, body untouched); the write is compared against the file's id, so an `override` id is recorded too; a failed write warns with the id. Thread routing of drafts left to Phase 3. 653 pass; lints unchanged.
