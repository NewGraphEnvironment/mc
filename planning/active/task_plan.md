# Task: [2/3] Email body: inline images, links in a new tab, table styles once, md-path integration tests (#43)

## Problem

`mc_deliver()` builds a `gm_html_body()` plus ordinary attachments. There is no way to reference an image from the HTML body, so `<img src="cid:...">` has nothing to point at. Inline `data:` URIs are stripped by Gmail. The only option inside mc today is a remote `https://` image, which Gmail proxies and other clients often block by default.

## Context (from plan-mode exploration)


Issue #43 batches four changes to the HTML body mc builds, closed by one PR:
#43 inline images (already built on `43-inline-images`, PR #44, one commit, 41 commits behind main),
#35 links open in a new tab, #42 table style declarations written once, and #10 integration tests
that send from a `.md` file with `sig = TRUE` and check all of it in a real inbox. No issue comments.

What exploration found that shapes the plan:

- **Merging main into the branch breaks scheduled sends with inline images.** Main's #47 work routes
  scheduled args through `write_scheduled_args()` (JSON). Probed: `jsonlite::toJSON(list(a = c(card = "x.png")), auto_unbox = TRUE)`
  gives `{"a":"x.png"}`: the Content-ID name is dropped, so at fire time `check_inline_images()` stops
  with "must be named" and the send fails. As a list it writes `{"card":"x.png"}`, which
  `read_json(simplifyVector = TRUE)` reads back as a named list that `chk_character` rejects. The paths
  are also not made absolute, as main now does for `attachments` (`R/mc_deliver.R:118-126`).
- **Merge conflicts:** `DESCRIPTION` (Imports gains `mime`) and `tests/testthat/test-mc_send.R` (the
  unmocked-send test, already fixed on main by #47; take main's version).
- **#42 cause confirmed, plus a bug next to it.** In `inline_table_styles()` (`R/mc_md_render.R:139`)
  the bare-tag pass writes `<table style="…">` and the style-prepend pass then matches it again.
  Probed separately: commonmark writes `<th align="left">` / `<td align="right">` for aligned columns,
  which no pass matches, so **aligned table cells get no border or padding at all**.
- **#35:** commonmark writes `<a href="u" title="T">` for a titled link, which the issue's
  `<a href="([^"]+)">` sketch misses. `inline_table_styles()` is called from both `mc_md_render()` and
  `mc_compose()` (`R/mc_compose.R:69`), so the link pass must run in both.
- **`check_inline_images()` reads any `cid:` in the text**, so prose such as "acid:" or a pasted
  `cid:` reference with no images errors the send. Tighten it to `src="cid:…"` / `src='cid:…'`.
- **Repo is public**, and PR #44's body ends with a session link. Remove it (attribution rule).

## Decided at the gate

Approved by the owner at the plan gate, 2026-11-05.

1. **Work on the existing branch `43-inline-images`**, not a new `43-2-3-…` branch, as the issue says.
   Bring main in with `git merge origin/main` (not a rebase). PR #44 becomes this move's PR, retitled to
   the batch, body gets `Fixes #35`, `Fixes #42`, `Fixes #10` and loses the session link.
2. **Fix the aligned `<th>`/`<td>` styling in the #42 pass.** Same function, same rewrite; leaving it
   means aligned tables keep rendering without borders.
3. **If Gmail web or Apple Mail also shows an attachment chip:** document it in `@param inline_images`
   as a known limit of gmailr's `multipart/mixed`, and draft a fork issue (`upstream-draft`) for
   `multipart/related` in gmailr. Nothing posted upstream without your word; no workaround in mc.
4. **Frontmatter `inline_images:` paths resolve against the working directory**, as `attachments:` do
   today. No change to path semantics in this move.

## Phase 0: Branch and baseline
- [x] Check out `43-inline-images`, `git merge origin/main`; resolve `DESCRIPTION` (keep `mime`) and `test-mc_send.R` (main's mocked test)
- [x] `devtools::document()` + `devtools::test()` on the merged tree: 501 pass, 1 fail, the Phase 1 defect caught by main's round-trip guard (findings.md)
- [x] Scaffold PWF in `planning/active/` and commit the baseline

## Phase 1: Inline images survive a scheduled send (#43)
- [x] Failing test: `inline_images` through `write_scheduled_args()` → `run_scheduled_send()` (mocked `mc_send`) keeps names and absolute paths
- [x] `mc_deliver()` scheduled branch: absolute directory per image (same `normalizePath(dirname)` + `basename` as attachments), written as a named list
- [x] `run_scheduled_send()`: turn a named list `inline_images` back into a named character vector before `mc_send()`
- [x] Callr backend keeps names (R object passed directly): one test

## Phase 2: Tighten the `cid:` scan (#43)
- [x] Tests: prose containing `cid:` with no images sends; `src='cid:x'` (single quotes) is found
- [x] `check_inline_images()` matches `src\s*=\s*["']cid:<token>` only

## Phase 3: Table styles once, aligned cells styled (#42)
- [x] Tests: each declaration appears once per `<table>`/`<th>`/`<td>`; aligned `<th align=…>`/`<td align=…>` get the style; kable `style="…"` attributes still merged; idempotent on a second call
- [x] Rewrite `inline_table_styles()` as one pass per tag: bare tag, tag with attributes and no style, tag with style (mutually exclusive)

## Phase 4: Links open in a new tab (#35)
- [ ] Tests: `[t](u)`, titled link, autolink and `www.` link gain `target="_blank" rel="noopener noreferrer"`; an `<a>` already carrying `target=` is left alone; `mailto:` links too; no-link HTML unchanged; `mc_compose()` output also rewritten
- [ ] `inject_link_target()` in `R/mc_md_render.R`: every `<a ` tag with `href` and no `target`; called from both `mc_md_render()` and `mc_compose()` next to `inline_table_styles()`
- [ ] Roxygen `@details` of `mc_md_render()` mentions it

## Phase 5: Integration tests from a `.md` file (#10)
- [ ] `test-integration.R`: `mc_send(path = <tmp .md>, sig = TRUE)` to al@ with a markdown link, an aligned table and an inline image (frontmatter `inline_images:` via `mc_md_send()` too); read the message back with `gmailr::gm_message()` and assert the signature, `target="_blank"`, each table declaration once, and an inline part with `Content-Id`
- [ ] Run `MC_RUN_INTEGRATION=true devtools::test(filter = "integration")` before the PR; test mail trashed by the existing safeguards

## Phase 6: The chip check (#43 acceptance)
- [ ] Send one `to_self = TRUE` message with an inline PNG; look at Gmail web (Chrome) and ask you to check Apple Mail
- [ ] Record the result in `findings.md`; apply gate decision 3 if a chip shows

## Phase 7: Wrap-up
- [ ] PR #44: retitle, extend body (Fixes #35/#42/#10, what changed), remove the session link
- [ ] Tick the batch checklist in #43's body as items land

## Validation

- [ ] Tests pass (`devtools::document() && devtools::test() && lintr::lint_package()`)
- [ ] Integration tests pass with `MC_RUN_INTEGRATION=true`
- [ ] `/code-check branch` clean (three-round floor)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive`, then push and update PR #44

**How each change is proved:** Phase 1 by a round-trip test that fails on the merged tree before the fix;
Phases 2-4 by unit tests written first, each watched red; Phase 5 by real mail read back from Gmail;
Phase 6 by eyes on two clients. A Plan-agent review of `task_plan.md` runs in the background after the baseline.

