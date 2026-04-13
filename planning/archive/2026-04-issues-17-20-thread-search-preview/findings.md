# Findings

## Existing code patterns (2026-04-13)
- `mc_thread_find()` / `mc_thread_read()` / helpers (`extract_header`, `extract_body`, `%||%`, `fetch_thread_drafts`) all live in `R/mc_thread_find.R`. Convention elsewhere is one-file-per-function, but the thread helpers are grouped — follow that grouping for `mc_thread_body_latest()`.
- gmailr calls used: `gm_messages(search, num_results)`, `gm_id()`, `gm_message()`, `gm_thread()`, `gm_drafts()`, `gm_draft()`.
- Status filter already uses `c("any","sent","draft")` pattern via `drafts = TRUE` in `mc_thread_read()` — new functions should use an explicit `status` arg for consistency with issue text.
- Input validation via `chk::chk_*`.
- Mocked tests use `local_mocked_bindings()` on gmailr functions.

## Date translation
- Gmail `after:` / `before:` accept `YYYY/MM/DD`. Accept Date or character YYYY-MM-DD; format with `format(as.Date(x), "%Y/%m/%d")`.
- Append to query with a single space.

## Quote stripping heuristic (#17)
- Strip trailing block where lines start with `^>` (one or more).
- Strip the "On <date>, <name> wrote:" attribution line immediately preceding the quoted block (English Gmail default). Covers the majority case; don't over-engineer for every locale.
- Trim trailing whitespace.
