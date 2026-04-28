# Findings — mc#31 YAML-driven Gmail labels

## Source survey (2026-04-25)

### `mc_send()` (R/mc_send.R)

- Returns `invisible(NULL)` after both draft (`gm_create_draft()`) and send (`gm_send_message()`) paths
- The gmailr return values are discarded — never assigned to a variable
- `gm_create_draft()` returns a draft resource with `$message$id`, `$message$threadId`
- `gm_send_message()` returns a message resource with `$id`, `$threadId`
- Two distinct call sites (sent with thread_id, sent without thread_id) — both need capture
- One distinct draft call site

### `mc_md_send()` (R/mc_md_send.R)

- Recognized frontmatter fields hardcoded in args list: `to`, `subject`, `cc`, `bcc`, `thread_id`, `attachments`, `from`, `sig`, `sig_path`
- Adding `labels` is one extra line: `args$labels <- meta$labels` (or include in main args list with the others)

### `mc_thread_modify()` (R/mc_thread_modify.R, v0.2.7)

- Signature: `mc_thread_modify(thread_id, add = NULL, remove = NULL)`
- Already handles user-label-name → label-id resolution
- Already errors on unknown label names with available list
- Returns invisibly via custom `gmail_modify_thread()` (gmailr 3.0.0 has a bug with `gm_modify_thread()`)
- Reusable as-is from `mc_send()` — no signature changes needed

### `mc_md_meta()` / `parse_frontmatter()` (R/mc_md_meta.R)

- Reads YAML via existing parser; new fields require no parser changes
- Just need to read `meta$labels` and pass through

## Existing test patterns

`test-mc_send.R`:

- Uses `local_mocked_bindings(.package = "gmailr")` for `gm_create_draft`, `gm_send_message`
- Mocks return whatever (currently the input `msg`) — can extend to return mock objects with `$threadId`
- `local_mocked_bindings` only takes ONE `.package` per call — for tests that need to mock both `gmailr::gm_send_message` AND `mc::mc_thread_modify`, must use **two separate calls** (lesson from issue #28)

## Draft-path label tradeoff

- `gm_create_draft()` does NOT support `thread_id` — drafts always land on a separate draft thread
- That draft thread's labels do NOT carry over to the conversation when user manually sends from Gmail UI
- Two design options:
  1. **MVP (this PR):** warn and skip on draft path. Simple, no surprises.
  2. **Fuller (deferred):** log labels to `~/.mc/pending_labels.json` keyed by draft message-id; `mc_labels_apply_pending()` reconciles after send-from-UI
- Going with MVP. Note in PR body that fuller version is deferred follow-up.

## Scope decisions

- **Including:** thread_id return, labels arg in mc_send, YAML labels: in mc_md_send, sent-path apply, draft-path warn
- **Deferring:** `labels_create = TRUE` (need a public `mc_create_label()` helper too — separate issue)
- **Unknown labels:** delegated to `mc_thread_modify()` existing error — already actionable
