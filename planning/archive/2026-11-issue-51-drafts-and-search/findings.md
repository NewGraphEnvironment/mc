# Findings — [3/3] Drafts and search (#51)

## Issue context

## Move 3 of 3: drafts and search

This issue carries a batch. One `/planning-init 51`, one branch, one pull request, which closes all of these:

- [ ] #49: `mc_thread_read()` classifies each message by its own labels (`DRAFT` means draft), lists a draft once, and drops drafts when `drafts = FALSE`. Fixes `mc_thread_body_latest(status = "sent")` returning an unsent draft.
- [ ] #50: `mc_message_find(status = "draft")` passes the query and the date filters to Gmail.
- [ ] #51 (this issue): `mc_draft()` / `mc_md_draft()` return the draft id and can replace that draft in place. Detail below.
- [ ] #55: a draft given `thread_id` is created in that thread (`users.drafts.create` with `message.threadId`), and drafts and sends into a thread carry `In-Reply-To` and `References`.
- [ ] #29: document Gmail search operators in `mc_thread_find()`, with examples. Docs only, and the same query surface as #50.

Order inside the move: #49 and #50 first, so drafts are labelled and found correctly, then #51 and #55 (both create drafts in `mc_deliver()`); #51's "delete or replace only by an id mc returned" rule depends on that.

**Start after** move 2 (#43) has merged; both edit `R/mc_deliver.R` and `R/mc_draft.R`. The pull request body carries `Fixes #49`, `Fixes #50`, `Fixes #51`, `Fixes #55`, `Fixes #29`.

**After merge:** all three moves are done. #12 (service account auth) stays parked: it needs a Workspace admin to grant domain-wide delegation, outside the repo.

---

**If we do it:** a caller that needs to change a draft it made (a corrected attachment, an edited body) replaces exactly that draft, and nothing else in the mailbox is touched. **If we never do:** the only way to replace a draft is to search the mailbox and delete what matches, and a match on recipient alone deletes the user's other drafts to that person, permanently (the Gmail API's `drafts.delete` does not trash).

## Problem

`mc_draft()` and `mc_md_draft()` create a Gmail draft and print `Draft created in Gmail. To: ...`, but the caller gets no supported handle on that draft. Inside `mc_deliver()`, `gmailr::gm_create_draft(msg)` returns the draft, and only its thread id is kept. So when a draft has to be regenerated, for example after re-rendering an attachment, a script has to list `gm_drafts()`, read each draft's headers and delete what matches.

That is easy to get wrong. A filter on the To header alone also matches drafts the user wrote by hand in Gmail to the same person, and `gm_delete_draft()` removes them for good. This happened in practice: three hand-written drafts were lost while one generated draft was being replaced.

## Proposed Solution

1. `mc_draft()` and `mc_md_draft()` return the created draft's id (invisibly, beside what they return now), and document it.
2. A `replace` argument (`mc_md_draft(path, replace = <draft id>)`) or an `mc_draft_update(id, ...)` that updates that draft in place through the Gmail API's `drafts.update`, so the id stays and no delete is needed.
3. Optionally, record the id in the markdown file's front matter (`draft_id:`) on creation, so re-running the same file replaces its own draft and only that one.

Whichever shape, deletion should only ever be by an id the caller received from `mc`, never by a search.




### Batched issue #49

**Batched into #51 (move 3 of 3):** worked and closed by that move's pull request. Plan from #51, not from here.

**If fixed:** `mc_thread_read()` and `mc_thread_body_latest(status = "sent")` report only what was actually sent. **If never:** an unsent draft reads as sent, including to `mc_thread_body_latest()`, whose documented use is recording what was sent.

## Problem

`gmailr::gm_thread()` returns a thread's draft messages along with its sent and received ones; a draft carries the `DRAFT` label. `mc_thread_read()` treats every message `gm_thread()` returns as sent:

```r
if (drafts) row$status <- "sent"
```

and with `drafts = TRUE` it then appends the same draft again from `fetch_thread_drafts()` as `"draft"`. Observed with mc 0.3.0 on a thread holding one received message and one unsent reply draft:

| from | status |
|---|---|
| sender | sent |
| me | **sent** (the draft) |
| me | draft (the same draft) |

The thread's message labels, read with `gm_thread()`, were `IMPORTANT,CATEGORY_PERSONAL,INBOX` and `DRAFT`, so nothing had been sent.

Consequences:

- `drafts = TRUE`: a draft is listed twice, once labelled `"sent"`.
- `drafts = FALSE`: the draft is still returned, with no status column to tell it apart.
- `mc_thread_body_latest(status = "sent")` filters on that column, so it can return an unsent draft's body.

## Proposed Solution

Classify each message from `gm_thread()` by its own labels: `"DRAFT" %in% msg$labelIds` gives `"draft"`, anything else `"sent"`. Then drop DRAFT-labelled messages when `drafts = FALSE`, and stop appending `fetch_thread_drafts()` (or keep it only to de-duplicate by message id). That also removes its limit, the 50 most recent drafts account-wide, which misses an older draft in the thread.

A test with a mocked `gm_thread()` returning one INBOX and one DRAFT message would pin all three cases above.



### Batched issue #50

**Batched into #51 (move 3 of 3):** worked and closed by that move's pull request. Plan from #51, not from here.

**If fixed:** `mc_message_find(query, status = "draft")` returns the drafts that match the query. **If never:** a draft search returns the newest drafts on any subject, which reads as a set of matches.

## Problem

The `"sent"` branch of `mc_message_find()` passes the query to Gmail (`paste(query, "-in:drafts")`), but the draft branch ignores both the query and the `after`/`before` filters:

```r
all_drafts <- gmailr::gm_drafts(num_results = n)
```

So `status = "draft"` returns the `n` most recent drafts in the account, and `status = "any"` mixes those into the matches for the query. Observed with mc 0.3.0: a `subject:"..."` query matching one draft returned that draft plus nine unrelated drafts, all labelled `"draft"`.

## Proposed Solution

Search drafts through the same route as sent mail: `gmailr::gm_messages(search = paste(query, "in:drafts"), num_results = n)`. The draft messages have their own ids and labels, so `message_row(msg, status = "draft")` works unchanged. (The Gmail API's `drafts.list` also takes a `q` parameter if keeping the drafts endpoint is preferred.) Add a test with a mocked search to show the query reaches the draft branch.



### Batched issue #55

**If we do it:** a reply drafted from a markdown file lands in the conversation it answers, ready to review and send from the thread, and the recipient's mail client threads it too. **If we never do:** every reply draft lands as a new conversation, so the user copies its body into a reply by hand, and the copy is what goes out, not the rendered draft with its signature and attachments.

## Problem

`mc_draft()` and `mc_md_draft()` accept `thread_id`, but the draft never joins the thread. `mc_deliver()` warns and creates a standalone draft, because `gmailr::gm_create_draft()` (gmailr 3.0.0) takes no thread id: it uploads the raw message with `uploadType = "media"` and has nowhere to put one. `gmailr::gm_send_message()` does accept `thread_id`, which is why `mc_send()` can reply into a thread and `mc_draft()` cannot.

The Gmail API itself supports it. `users.drafts.create` takes a draft resource whose `message.threadId` places the draft in an existing thread. For Gmail to thread a message reliably, the API docs also ask that the message carry `In-Reply-To` and `References` headers naming the message being answered, and a matching subject. mc sets neither header on drafts or sends, so a reply sent with `mc_send(thread_id = )` can join the thread in the sender's Gmail and still arrive as a new conversation in a recipient's client that threads by headers.

## Proposed Solution

1. Create a draft with `thread_id` through `users.drafts.create` with `message.threadId` set (a JSON body with `raw` and `threadId`, as `gm_send_message()` already builds), in place of the warning.
2. When `thread_id` is given to a draft or a send, read the thread's latest message and set `In-Reply-To` to its `Message-ID` and `References` to its `References` plus that `Message-ID`. Prefix the subject with `Re: ` when the frontmatter subject lacks it.
3. Upstream, `gm_create_draft()` could take `thread_id` the way `gm_send_message()` does. Worth offering to gmailr as an issue; mc should not wait on it, and may call the endpoint directly until then.
4. Tests: a mocked draft request carries `threadId` and both headers; with no `thread_id` the request is unchanged.

Touches `R/mc_deliver.R` and `R/mc_draft.R`, the same files as #51, so it fits that move.


### Batched issue #29

**Batched into #51 (move 3 of 3):** worked and closed by that move's pull request. Plan from #51, not from here.

## Problem
`mc_thread_find()` is a pass-through to Gmail's search, which accepts
the full Gmail query operator set (`from:`, `to:`, `subject:`,
`has:attachment`, `newer_than:`, `after:`, `before:`, `is:unread`,
etc.). The function docs don't mention this, so new users don't know
they can use those operators.

## Proposed Solution
Add to `mc_thread_find()` roxygen:

- One-sentence note that `query` accepts Gmail search operators.
- Link to Google's operator reference:
  https://support.google.com/mail/answer/7190
- 2-3 example queries in `@examples` covering the common cases
  (`from:`, `newer_than:`, combined).

Surfaced while evaluating the Claude.ai Gmail MCP against mc — the
MCP's schema documents the operator set inline, which made the gap in
mc's docs obvious.



## Exploration (plan mode, 2026-11-05)


- `R/mc_deliver.R:195-217`: a draft goes through `gmailr::gm_create_draft(msg)` (gmailr 3.0.0: `uploadType = "media"`, no thread id), and only the thread id is kept. gmailr has **no** `drafts.update` and no thread-aware draft create.
- mc already calls the Gmail API directly: `R/mc_thread_modify.R:102` does `httr::POST(url, body, encode = "json", gmailr::gm_token())`. `httr` and `gargle` are already in Imports. `gm_send_message()` builds the JSON shape we need (`{threadId, raw: base64url}`) on the plain endpoint, and mc_send uses that today, attachments included.
- Headers: setting `msg$header[["In-Reply-To"]]` on a gmailr mime object writes it into the message (checked).
- `R/mc_thread_find.R:127`: `if (drafts) row$status <- "sent"` for every message, then `fetch_thread_drafts()` (50 newest drafts account-wide) appends them again. `extract_header()` matches names exactly, and `Message-ID` arrives as `Message-Id` from some senders.
- `R/mc_message_find.R:60`: the draft branch is `gm_drafts(num_results = n)`, with no query.
- No repo outside mc uses the return value of `mc_draft()` / `mc_md_draft()` (grepped `~/Projects/repo`).
- Tests: `local_mocked_bindings(.package = "gmailr")` in the draft/send tests, `mockery::stub` in the thread/message tests. `test-mc_send.R:463` asserts mc_send never drafts; `test-mc_draft.R` asserts mc_draft never sends.

## Live Gmail measurements (integration run 2026-11-05 23:51Z, `MC_RUN_INTEGRATION=true`, 67 pass)

Answers to the plan review's assumptions, measured by `tests/testthat/test-integration.R` (the `# --- Drafts by id` block):

- **A1 (JSON route size):** an 8 MB random attachment survives `gm_create_draft()` and then `PUT drafts/{id}` with the message as base64url JSON on the non-upload endpoint; the replaced draft's attachment part reports > 7.9e6 bytes. No multipart-upload fallback needed at this size.
- **A2 (thread on replace):** a `PUT` that carries `threadId` keeps the draft in its thread; a `PUT` without one (an explicit `mc_draft(draft_id =, to_self = TRUE)`) moved it to a new thread. Documented on `mc_draft()`: pass the same `thread_id` when replacing; `mc_md_draft(to_self = TRUE)` never touches the tracked draft.
- **A3 (labels on replace):** a label given again on replace is on the new message; a replace without `labels` dropped it. Documented.
- **A4 (malformed id):** a message id (`1a1a3d39782240d9`) passed as `draft_id` gets the same 404 as a deleted draft, so it warns and creates a new draft. Documented ("the id is not a draft id").
- Stale id (deleted by id, then replaced): warns, new id. `mc_message_find(status = "draft")` with a subject query returned exactly the one tagged draft. A threaded draft got `Subject: Re: …`, `In-Reply-To` and `References`, and `mc_thread_read(drafts = TRUE)` listed it once as a draft. No test drafts were left in the mailbox afterwards.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Python heredoc edits turned R's `"\\s\\S"` into `"\s\S"` (an R parse error) | Restored with `sed`; check regex escapes after any Python-driven edit of R strings |
