# Code-check review, round 1: branch 51-3-3-drafts-and-search-return-and-replace

## Checklist read

- **code-check.md:** I read the prose of all 14 H3s under `## Mechanisms` (table rows skipped), plus "Percent-encode a URL at construction, not at consumption". 22 of 37 H3s not read.
- **code-check-r.md:** 17 sections read:
  - "Read-back shape must match write-back shape"
  - "`tryCatch(warning = )` DISCARDS the value the expression produced"
  - "`expect_message(expr, regexp)` checks only the FIRST condition, so a progress line hides the message under test"
  - "`$` on a list partial-matches, so a longer sibling key answers for a missing one"
  - "`tryCatch()` nests its handlers, so a `stop()` in one is caught by a later one"
  - "A `function(...)` mock hides arguments the real callee no longer accepts"
  - "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared"
  - "Under `R CMD check`, tests run from a temp dir against the INSTALLED package"
  - "Cross-function consistency for label/string normalization"
  - "`identical()` on two reader results tests the reader, not the file"
  - "testthat 3e `expect_message()` returns the condition, not the expression's value"
  - "`nzchar(NA)` is TRUE — non-empty checks silently pass NA"
  - "`paste()` with a zero-length argument returns length ONE, not zero"
  - "`tempfile()` lives in the session tempdir, so a path printed in an error names a file R is about to delete"
  - "Tests that silently do not run"
  - "A `skip_if_not()` skips only its own `test_that()` block"
  - "`expect_false(identical(x, y))` cannot fail when the two are different types"

  100 of 117 not read.
- **code-check-shell.md:** none read, because the diff has no shell code. 70 of 70 not read.
- **code-check-spatial.md:** none read, because the diff has no spatial code. 94 of 94 not read.

Unit tests for the changed areas pass on the working tree: `devtools::test(filter = "mc_draft|mc_md_draft|reply_headers|mc_send|mc_message_find|mc_thread_read")`.

## Findings

- **[severity: bug]** R/mc_md_draft.R:50 (and :53) — `override = list(to_self = TRUE)` overwrites the file's tracked draft with a to-self test copy and takes it out of its thread.
  - **Why:** the guard reads the `to_self` formal. `md_dispatch_args()` applies `override` after that, so `args$to_self` can be `TRUE` while the formal is `FALSE`. The file's `draft_id` is then passed on, and `mc_deliver()`'s to_self branch drops `to`, `cc`, `bcc` and `thread_id`. The result is a PUT to the real draft, addressed to the sender, with no `threadId`.
  - **Probe:** I wrote a file with `to: client@x.com`, `thread_id: t9` and `draft_id: "r-real"`, then ran `mc_md_draft(p, override = list(to_self = TRUE))` with the transport mocked. Output: `Draft r-real replaced. To: me@x.com`, PUT `draft_id: r-real`, `threadId sent: NULL`.
  - **Impact:** this is exactly what the roxygen ("the tracked draft is left alone") and the "to_self neither replaces nor records" test promise cannot happen. The client-addressed draft, including any edits made to it in Gmail, is lost, and mc never deletes or restores drafts.
  - **Fix:** take the effective value, `to_self <- isTRUE(args$to_self)`, after `md_dispatch_args()` and before both uses. Alternatively, refuse `to_self` in `override`, as `mc_md_send()` refuses `draft_id`.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies" ; code-check.md "A fix lands in one of two callers that share a harness"

- **[severity: security]** R/mc_deliver.R:358-374 — `reply_headers()` copies `Message-ID`, `References` and `In-Reply-To` from the thread's latest message into the outgoing headers without validating them.
  - **Why:** `mid` is only `trimws()`'d, and the References tokens come from `<[^<>]+>`, which matches CR and LF inside the brackets. gmailr's `format_headers()` pastes header values raw (`header_encode_text` returns ASCII unchanged).
  - **Probe:** a mocked thread whose latest message had `Message-ID: "<a@x>\r\nBcc: evil@attacker.example"` and `References: "<z@x\r\nCc: cc@attacker.example>"` produced an outgoing MIME from `mc_send(..., thread_id = "t9")` with extra `Bcc: evil@attacker.example` and `Cc: cc@attacker.example>` header lines.
  - **Exposure:** the latest message in a thread is often an inbound message from a third party, and the send path parses that raw message for recipients.
  - **Not verified:** that Gmail's API ever returns a CR/LF in a header value, for example by decoding an RFC 2047 encoded word in a crafted `Message-ID`. So whether this can be reached in practice is open, but mc does nothing to stop it.
  - **Fix:** build both headers only from tokens matching `^<[^<>\s]+>$` (extract with `<[^<>[:space:]]+>`). If the parent's `Message-ID` is not one such token, warn and thread by id only, as the no-Message-ID branch already does.
  - **Rule:** none

- **[severity: fragile]** R/mc_md_render.R:168 (`frontmatter_set`, append branch) — if a file's last frontmatter key is a block scalar with default (clip) chomping, its `draft_id` can never be recorded. Every `mc_md_draft()` run then creates a new draft.
  - **Why:** the captured block excludes the newline before the closing `---`. Appending `eol + line` gives the final scalar a trailing newline it did not have (`notes: |` value `"call before sending"` becomes `"call before sending\n"`). The read-back guard correctly refuses that change.
  - **Probe:** frontmatter ending in `notes: |\n  call before sending`, `mc_md_draft()` run three times with transport mocked. Each run warned `Draft r-N created, but its id was not recorded ... would not read back as written`. Three drafts were created and the file still had no `draft_id`. With `|-` it recorded fine.
  - **Impact:** mc never deletes drafts, so each re-run leaves another copy in Gmail.
  - **Fix:** insert the new line at the top of the block, immediately after the opening `---` line, so no trailing scalar's chomping changes. The read-back guard stays as it is.
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode"

## Notes (not findings)

- The checklist rule "`expect_message(expr, regexp)` checks only the FIRST condition" does not hold in this testthat install. `expect_message(mc_md_send(p), "Draft r-1 ...")` passes even though `mc_send()` emits "Sent (new thread)..." first. The new `expect_message` assertions are therefore not broken.
- The integration test's malformed-id probe (`tryCatch(warning = )`) unwinds at the not-found warning. In `write_draft()` that warning comes before `gm_create_draft()`, so no draft is leaked, but the "created" arm of that probe can never be reached.
