# Code-check round 3: branch `51-3-3-drafts-and-search-return-and-replace` at e87e699

## Checklist read

- **code-check.md**: the prose (table rows skipped) of all 14 H3s under `## Mechanisms`: A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice. Also: Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1; Percent-encode a URL at construction, not at consumption. **16 read, 21 not read.**
- **code-check-r.md**: Read-back shape must match write-back shape; `$` on a list partial-matches, so a longer sibling key answers for a missing one; `[[` on a named ATOMIC vector with an absent key is an error, not `NULL`; `fs::file_move()` onto an existing directory nests the source inside it; A `function(...)` mock hides arguments the real callee no longer accepts; `tryCatch()` nests its handlers, so a `stop()` in one is caught by a later one; R's `yaml` returns a mixed int/float sequence as a list, not a numeric vector; Cross-function consistency for label/string normalization; `identical()` on two reader results tests the reader, not the file; `nzchar(NA)` is TRUE — non-empty checks silently pass NA; `tryCatch(warning = )` DISCARDS the value the expression produced; `expect_message(expr, regexp)` checks only the FIRST condition, so a progress line hides the message under test; `sub()` takes one replacement, not one per element. **13 read, 104 not read.**
- **code-check-shell.md**: A variable in a sed replacement is parsed, so its `\` and `&` are not literal (read for its R analogue, `sub()` in `frontmatter_set()`). **1 read, 69 not read.** No shell in the diff.
- **code-check-spatial.md**: **0 read, 94 not read.** No spatial code in the diff.

## Mechanism

**The shared assumption: the object a check (or a read) resolves is the same object the action then touches.** All four earlier findings are that assumption failing at one boundary or another:

- R1 to_self: the guard read the `to_self` formal; the action used `args$to_self` after `override` was merged.
- R1 header injection: the check was "this is a header value"; what got written was whatever bytes a stranger put there, which the MIME writer reads as more header lines.
- R1 append position: the writer added a line at a place in the *text*; the YAML parser read that place as inside the block scalar above it.
- R2 `$`: the lookup asked for `draft_id`; `$` resolved a different key, `draft_id_old`.

Each place in the changed code where that resolution happens, with a verdict:

| # | Place | What the check resolves vs what the action touches | Verdict |
|---|---|---|---|
| 1 | `mc_md_draft()` `test_copy <- isTRUE(args$to_self)` (R/mc_md_draft.R:51) | read from the same `args` that `do.call(mc_draft, args)` receives, after `override`; `to_self` is always an exact key in `args` | safe |
| 2 | `mc_md_draft()` `is.null(args$draft_id)` (l.52) | `$` read on `args`, which can hold override keys. An override such as `draft_idx` would partial-match and suppress the file's id, but `mc_draft()` then rejects `draft_idx` as an unused argument (it reaches `...`), so nothing is created | safe (errors) |
| 3 | `mc_md_draft()` `args$draft_id <- file_id` | `$<-` assigns exactly, no partial match | safe |
| 4 | `mc_md_draft()` `file_id` vs `md_dispatch_args()` meta | two parses of one file through one parser (`mc_md_meta()` -> `parse_frontmatter()`), both `[[` | safe |
| 5 | `mc_md_draft()` `res$draft_id` (l.54) | `res` is `mc_deliver()`'s own `list(draft_id, thread_id, message_id)`: exact keys | safe |
| 6 | `mc_md_draft()` recording condition `!identical(new_id, file_id)` | compares Gmail's returned id with the file's; a 404 fallback gives a new id and records it, a replace gives the same id and writes nothing | safe |
| 7 | `mc_md_send()` `"draft_id" %in% names(override)` guard, and the post-send `[[` read | exact name test on override; a near-miss key errors as unused in `mc_send()` | safe |
| 8 | `md_dispatch_args()` 13 `meta[[...]]` reads; `index_row()` 6; `mc_preview()`/`preview_header()` 9 | all `[[` (R2). Grepped `R/` for `meta\$`: none left. On a non-list `meta`, `[[` errors where `$` errored before, and `md_dispatch_args()` stops on the missing-field check first | safe |
| 9 | `frontmatter_set()` key search `(?m)^draft_id:` vs the YAML parser's key | a text match at column 0 can disagree with the parser (quoted key, `draft_id :`, a flow mapping across lines), but every disagreement is caught by the read-back through `parse_frontmatter()`, compared with `[`/`[[` (exact), before the rename | safe (guarded) |
| 10 | `frontmatter_set()` insertion point | now the block's first line, which no block scalar can contain; read-back guards the rest | safe |
| 11 | `frontmatter_set()` `sub(pattern, line, ...)` | `line` is the replacement; value restricted to `[A-Za-z0-9_-]`, so no `\` or `&`-style backreference can land in it | safe |
| 12 | **`frontmatter_set()` read path vs write path** | `readBin(path)` and the read-back guard both **follow a symlink** to its target; `file.rename(tmp, path)` **replaces the link itself**. Probed: after `frontmatter_set(link, ...)`, `link` is a regular file and the target has no `draft_id`. Same for a hard link: the other name keeps the old bytes | **defect** (Finding 1) |
| 13 | `frontmatter_set()` `Sys.chmod(tmp, file.info(path)$mode)` | follows the link: target's mode, applied to the file that replaces the link | safe (part of 12) |
| 14 | `reply_headers()` Message-ID | validated as a whole-string msg-id (`^<[^<>[:space:]]+>$`, TRE; probed: `\r`, `\v` and space all rejected), after `trimws()` | safe |
| 15 | `reply_headers()` References / In-Reply-To tokens | filtered token by token with the same `msg_id` pattern, so what is checked is what is copied | safe |
| 16 | `reply_headers()` header names written into `msg$header` | fixed literals `In-Reply-To`, `References`; gmailr's `header_encode_text()` RFC 2047-encodes a non-ASCII value rather than passing raw bytes | safe |
| 17 | `reply_headers()` parent chosen by `DRAFT`/`TRASH`/`SPAM` labels vs `is_draft_message()` | both read `unlist(<msg>$labelIds)` for the literal `DRAFT` | safe (consistent) |
| 18 | `mc_thread_read()` filter and status column | one predicate, `is_draft_message()`, used for both | safe |
| 19 | `mc_message_find()` search filter (`in:drafts` / `-in:drafts`) vs status column (labels) | status comes from each message's own label, so a row can never be mislabelled by the filter that found it | safe |
| 20 | `$` reads on Gmail resources (`thread$messages`, `m$labelIds`, `msg$payload`, `h$name`, `h$value`, `res$threadId`, `res$message`, `payload$parts`, `payload$body$data`) | checked each resource's documented key set (Thread, Message, MessagePart, MessagePartBody, Header, Draft) for prefix siblings: none, so `$` cannot resolve another key | safe |
| 21 | `extract_header()` now case-insensitive | first header with that name, any case; only `Message-ID` and the reply headers flow onward, and they pass through 14/15 | safe |
| 22 | `mc_deliver()` `to_self` then `thread_id` | `thread_id` is set to NULL under `to_self` before `reply_headers()` and before the placement warning, so no thread is read or written | safe |
| 23 | `mc_deliver()` placement warning `sent_thread_id` vs `thread_id` | Gmail's returned thread vs the requested one, both after to_self | safe |
| 24 | `write_draft()` 404 -> create | the 404 check is on the PUT to that id; the fallback carries the same `thread_id` | safe |
| 25 | `gmail_draft_request()` URL vs body id | `URLencode(draft_id, reserved = TRUE)` in the path, the same `draft_id` in the JSON body | safe |
| 26 | scheduled send carrying `thread_id` | `reply_headers()` and `Re: ` run at fire time in `mc_send()`; `draft_id` is not a scheduled arg (by design) | safe |

## Findings

- **[severity: fragile]** R/mc_md_render.R:181-184 (`frontmatter_set()`, `tmp`/`file.rename(tmp, path)`) — the file is read through a symlink but written by renaming over the link. When the `.md` handed to `mc_md_draft()` is a symlink, the first recorded `draft_id` turns the link into a regular file and leaves the target without the id, and nothing says so (the message reads "Recorded draft_id ... in <link>"). Afterwards the two paths have split: a run through the target path finds no `draft_id` and makes a second draft each time, and edits made to the target no longer reach the link path, so a run there replaces the draft with stale text. Probed in /private/tmp: after `frontmatter_set(link, "draft_id", "r-1")`, `Sys.readlink(link)` is `""` and `mc_md_meta(real)[["draft_id"]]` is NULL. A hard link splits the same way. The fix: resolve the path before reading and writing (`path <- normalizePath(path, mustWork = TRUE)` at the top of `frontmatter_set()`, which follows symlinks), so the temp file goes beside the target and the rename replaces the target. No write-and-rename can keep a hard link (base `file.info()` has no link count either; `fs::file_info()$hard_links` does), so leaving hard links as a known limit is reasonable.
  - **Rule:** none (closest: code-check.md "A guard that fails toward pass", The write path; it is this round's mechanism, read from one object and written to another)

Nothing else found. The R1 and R2 fixes hold: no `$` reads of frontmatter are left in `R/`, the guard and the value `mc_draft()` receives come from one `args`, and reply-header values are checked token by token by the same pattern that selects what gets copied. The 238 unit tests across the touched files pass in a clone at e87e699 (0 failed, 0 errors).
