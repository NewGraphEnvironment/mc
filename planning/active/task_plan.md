# Task: [3/3] Drafts and search: return and replace a draft by id, draft status in threads, draft query, query docs (#51)

Batch closing #49, #50, #51, #55, #29. From #51's Problem:


`mc_draft()` and `mc_md_draft()` create a Gmail draft and print `Draft created in Gmail. To: ...`, but the caller gets no supported handle on that draft. Inside `mc_deliver()`, `gmailr::gm_create_draft(msg)` returns the draft, and only its thread id is kept. So when a draft has to be regenerated, for example after re-rendering an attachment, a script has to list `gm_drafts()`, read each draft's headers and delete what matches.

That is easy to get wrong. A filter on the To header alone also matches drafts the user wrote by hand in Gmail to the same person, and `gm_delete_draft()` removes them for good. This happened in practice: three hand-written drafts were lost while one generated draft was being replaced.

## Decided at the gate (user, 2026-11-05)

1. **Return shape:** `mc_draft()` / `mc_md_draft()` return `list(draft_id, thread_id, message_id)` invisibly. This breaks anyone reading the bare thread id, so the release is 0.5.0, with a NEWS line. `mc_send()` still returns the thread id.
2. **Replace shape:** a `draft_id` argument on `mc_draft()`, plus a `draft_id:` frontmatter field for `mc_md_draft()`. Replacing goes through Gmail's `drafts.update` (PUT `drafts/{id}`), so the id stays the same and nothing is deleted. mc never deletes a draft.
3. **Frontmatter write-back: yes.** When `mc_md_draft()` creates a draft, it adds or updates one `draft_id:` line inside the YAML block. **On git (asked at the gate):** mc does not touch git. The write changes only that one line, happens only after Gmail confirms the draft, keeps every other byte, and the message names the file. The change then shows up in `git diff` like any other edit, and you commit it with the `.R` file. Running git from a mail package would mean committing in someone else's repo without asking, so it stays out. Two consequences, both harmless under decision 4: a draft id belongs to one mailbox, so a colleague running the same file gets "not found", a fresh draft, and their own id written in. And a `to_self` run records its id too, so the next real run replaces the test draft rather than leaving it behind.
4. **Stale id** (the draft was sent or deleted, Gmail answers 404): warn, create a new draft, return its id. With write-back, the file gets the new id.

## Phase 1: Thread and message drafts are classified by their own labels (#49, #50)

- [x] Tests first: a mocked `gm_thread()` holding one INBOX message and one DRAFT message. With `drafts = TRUE`: two rows, statuses `sent` and `draft`, no duplicate. With `drafts = FALSE`: one row, no draft. `mc_thread_body_latest(status = "sent")` returns the INBOX body.
- [x] `mc_thread_read()`: status comes from `"DRAFT" %in% msg$labelIds`. DRAFT messages are dropped when `drafts = FALSE`. Remove `fetch_thread_drafts()` (no longer used) and move the shared body extraction into one helper.
- [x] Tests first: a mocked `gm_messages()` captures the search string. `status = "draft"` sends `<query> in:drafts` with the date filters, `"sent"` sends `<query> -in:drafts`, and `"any"` sends the bare query, with each row's status taken from its labels.
- [x] `mc_message_find()`: drafts are found through `gm_messages(search = )` with the status taken from labels, and `gm_drafts()`/`gm_draft()` are no longer used. Update the `status` docs: `"any"` now returns up to `n` in total, not `n` per branch.
- [x] Update the existing thread/message tests that stub `fetch_thread_drafts` / `gm_drafts`.

## Phase 2: Return and replace a draft by id (#51)

- [x] Internal `gmail_draft_request(raw, thread_id = NULL, draft_id = NULL)` in `R/mc_deliver.R`: POST `drafts` (create) or PUT `drafts/{id}` (update), with a JSON body `{message: {raw, threadId?}}` (`id` added on update), through `httr` + `gmailr::gm_token()` + `gargle::response_process()`, like `mc_thread_modify()`. A 404 on update is returned as a classed condition so the caller can fall back.
- [x] Tests first (`local_mocked_bindings` on `gmail_draft_request` and `gm_create_draft`):
  - a plain draft still goes through `gm_create_draft()`, so the request is unchanged (#55 item 4), and returns `list(draft_id, thread_id, message_id)`
  - `draft_id = "r1"` sends a PUT for `r1` and returns `r1`
  - a 404 on update warns, creates a new draft and returns the new id
  - `mc_send()` never reaches `gmail_draft_request()`, and `mc_draft()` never reaches `gm_send_message()`
- [x] `mc_deliver()` gains `draft_id` (with a chk check). Draft branch: if `draft_id` or `thread_id` is given, use `gmail_draft_request()`, otherwise `gm_create_draft()`. Return the list for drafts. Labels still apply by thread id. Message: `Draft created` or `Draft <id> updated`.
- [x] `mc_draft()` gains `draft_id = NULL` with docs; `to_self` keeps `draft_id` (it names our own draft, not a recipient).
- [x] `mc_md_draft()`: `md_dispatch_args()` passes `meta$draft_id`. After a draft is created or replaced with a new id, write `draft_id:` into the frontmatter through one helper, `frontmatter_set()`, in `R/mc_md_render.R`: it replaces an existing `draft_id:` line or adds one before the closing `---`, and leaves the body and every other line byte for byte. Tests: round trip through `parse_frontmatter()`, an existing line replaced rather than duplicated, the body untouched (md5 of the part after the YAML block), CRLF and no trailing newline. `mc_md_send()` ignores `draft_id`.
- [x] Update every existing test that reads the old return value (`expect_equal(res, "draft_thread_001")` and the like).

## Review fold-in (review-plan.md, 2026-11-05)

- [x] B1: `mc_md_send()` errors on `override$draft_id`, tested against the real `mc_send()` signature; S3: it notes a frontmatter draft still in Gmail
- [x] G3: `mc_draft()` rejects `draft_id = ""`; `mc_md_draft()` treats `draft_id: ""` as absent
- [x] G4: `frontmatter_set()` re-parses the written temp file and refuses (original untouched) unless `draft_id` reads back and every other key is unchanged
- [x] G7 (corrects gate decision 3's to_self note): `mc_md_draft(to_self = TRUE)` neither uses nor records the file's `draft_id`; docs say a replace overwrites edits made in Gmail; G8: docs explain `message_id`

## Phase 3: A draft joins its thread, with reply headers on drafts and sends (#55)

- [x] Tests first: with `thread_id`, the draft request carries `threadId`, the raw message carries `In-Reply-To: <latest Message-ID>` and `References: <old refs> <latest Message-ID>`, and the subject gains `Re: ` (not when it already starts with `re:`, any case). The same headers go on `mc_send(thread_id = )`. With no thread id, the request is unchanged. The thread-id warning is gone.
- [x] Internal `reply_headers(thread_id)`: `gm_thread()`, latest message not labelled DRAFT, TRASH or SPAM; `extract_header()` ignores case (`Message-ID` / `Message-Id`). An unreadable thread is an error raised before anything is created or sent, naming the thread; a thread with no usable `Message-ID` warns and goes ahead with `threadId` only (A5). `References` falls back to the parent's `In-Reply-To` and keeps the first id plus the last 10 (A6, G9).
- [x] The 404 fallback keeps the thread (G6); warn when Gmail's returned threadId differs from the one asked for (G5).
- [x] Apply it in `mc_deliver()` after the scheduling branch (a scheduled send reads the thread when it fires, not when it is queued) and after `to_self` (which drops `thread_id`).
- [x] Remove the "cannot thread a draft" text from `mc_draft()` / `mc_md_draft()` docs and `README.md:136-139`, and document the reply headers on `mc_send()`.

## Phase 4: Query docs (#29)

- [ ] `mc_thread_find()` roxygen: one sentence saying `query` takes Gmail search operators, a link to https://support.google.com/mail/answer/7190, and examples with `from:`, `newer_than:`, `has:attachment` and a combined query. `mc_message_find()` points to it.

## Phase 5: Docs, NEWS, integration

- [ ] `devtools::document()`, `NEWS.md` entry under the development heading (breaking return shape; drafts in threads; reply headers; label-based draft status; draft queries), `pkgdown::check_pkgdown()`.
- [ ] Integration probes from the review: stale id (delete by id, then replace → warning, new id); update of a threaded draft keeps threadId and headers (A2); attachment over 5 MB on create and update through the JSON route (A1); labels after a replace (A3); status for a malformed id (A4). Record each in findings.md.
- [ ] Integration tests (`MC_RUN_INTEGRATION=true`): create a draft, replace it by the returned `draft_id`, and check the id is the same with the new body; a draft with an attachment, created and updated through the JSON path; send to self, draft into that thread, and check the threadId and both headers; `mc_message_find(status = "draft")` finds only the tagged draft. Every draft the tests make is deleted in `withr::defer()` by the id mc returned.

## Owed at the end (reported, done after merge)

- [ ] Draft (not post) a short gmailr issue offering `thread_id` on `gm_create_draft()` and a `gm_update_draft()`, following the upstream rules (fork issue labelled `upstream-draft`, AI disclosed). Show it to you; nothing is posted without your word.

- [ ] File a soul issue: `conventions/communications.md` and the `email-draft` skill say drafts cannot join a thread, and the skill commits the `.md` before `mc_md_draft()` writes `draft_id:` (S1, S2).

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

How each change is proved: unit tests written before each fix, red on the current code (#49's double row, #50's ignored query, #55's missing threadId) and green after; restore-the-bug check on the never-sends / never-drafts guards; `devtools::test()` + `lintr::lint_package()` clean per commit; integration run against Gmail before the PR is opened (replace keeps the id, the thread draft lands in the thread, the attachment survives the JSON path). The PR body carries `Fixes #49`, `Fixes #50`, `Fixes #51`, `Fixes #55`, `Fixes #29`.

