# Task: Split mc_send() into mc_draft() and mc_send(); rename test to to_self (#39)

`mc_send()` drafts or sends depending on `draft`, a single boolean, so one
character separates a reversible act from an irreversible one. The argument
that reads as protective — `test` — is not: the `test` branch only rewrites
recipients (`to <- from`, cc/bcc/thread_id cleared); `draft` alone selects
`gm_create_draft()` vs `gm_send_message()`.

On 2026-08-26 this produced a real incident: an enquiry went to nine external
recipients when a draft was intended. Email cannot be recalled.

Sending must be *named*, not configured. The verb moves into the function name,
so nothing passed to `mc_draft()` can send.

## Design

```r
mc_deliver(..., .draft)   # internal, not exported — current mc_send() body
mc_draft(...)             # .draft = TRUE.  No send_at / scheduler.
mc_send(...)              # .draft = FALSE. Keeps send_at / scheduler.
mc_md_draft(path, ...)    # -> mc_draft
mc_md_send(path, ...)     # -> mc_send
```

`test` becomes `to_self` on all four. `draft` disappears entirely — no
deprecated alias, since a path that still accepts it preserves the ambiguity
being removed.

## Phase 1 — Tests first (failing)

- [ ] `tests/testthat/test-mc_draft.R` (new): creates a draft; `to_self = TRUE` redirects to `from` and strips cc/bcc/thread_id; warns on `thread_id`; applies labels to the draft thread
- [ ] `test-mc_draft.R`: `mc_draft()` never calls `gm_send_message()` — mock it to `stop()` and assert no error
- [ ] `test-mc_draft.R`: `mc_draft()` rejects `send_at` / `scheduler`
- [ ] `test-mc_send.R`: rewrite to send-only — drop every `draft =`; `to_self = TRUE`; `thread_id` sends into thread; `send_at` / `scheduler` paths retained
- [ ] `test-mc_send.R`: passing `draft =` or `test =` errors
- [ ] `tests/testthat/test-mc_md_draft.R` (new): frontmatter dispatch to `mc_draft()`; `to_self` passes through
- [ ] `test-mc_md_send.R`: rewrite to send-only; `override = list(draft = ...)` and `list(test = ...)` error naming the replacement
- [ ] Run: fails as expected

## Phase 2 — Core split

- [ ] Extract current `mc_send()` body into internal `mc_deliver()` with `.draft` arg; `@keywords internal`, no export
- [ ] `R/mc_draft.R`: `mc_draft()` — `.draft = TRUE`, no `send_at` / `scheduler`, explicit error if either is supplied
- [ ] `R/mc_send.R`: `mc_send()` — send-only, retains `send_at` / `scheduler`
- [ ] Rename `test` → `to_self` in both signatures and in `mc_deliver()`
- [ ] Move the `gm_create_draft()`-cannot-thread warning into the draft path
- [ ] `devtools::document()`; confirm NAMESPACE exports `mc_draft`, not `mc_deliver`
- [ ] Phase 1 draft/send tests pass

## Phase 3 — Frontmatter wrappers

- [ ] `R/mc_md_draft.R`: `mc_md_draft(path, to_self = FALSE, override = list())` → `mc_draft()`
- [ ] `R/mc_md_send.R`: send-only, `to_self`, → `mc_send()`
- [ ] Both: guard `override` against `draft` / `test` keys, erroring with the replacement named
- [ ] Phase 1 md tests pass

## Phase 4 — Docs, integration tests, release

- [ ] Runnable `@examples` on `mc_draft()` / `mc_md_draft()`; update `mc_send()` / `mc_md_send()` examples
- [ ] `test-integration.R`: `draft = FALSE, test = TRUE` → `mc_send(to_self = TRUE)`
- [ ] `README.md`: quick-start and threading sections
- [ ] `CLAUDE.md`: reword the BCC convention in terms of `mc_send()` vs `mc_send(to_self = TRUE)`
- [ ] `NEWS.md`: 0.3.0 breaking entry
- [ ] `devtools::document() && devtools::test() && lintr::lint_package()` clean
- [ ] `DESCRIPTION` → 0.3.0 as the final commit

## Phase 5 — Downstream (compost, separate PR)

- [ ] Not on this branch. ~35 `draft <- TRUE` scripts → `mc_md_draft()`; 8 historical `draft <- FALSE` scripts go inert. Track separately.

## Validation

- [ ] `devtools::test()` green; `lintr::lint_package()` clean
- [ ] Manual: `grep -rn "draft *=" R/ | grep -v thread_find | grep -v message_find` returns nothing
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
