# Findings — [2/3] Email body (#43)

## Issue context

## Move 2 of 3: what an email body can carry

This issue carries a batch. One `/planning-init 43`, one branch, one pull request, which closes all of these:

- [ ] #43 (this issue): inline images. Already built on branch `43-inline-images`, PR #44. Bring `main` in first (it has moved since September), then settle the open check below: does Gmail web / Apple Mail also show an attachment chip?
- [ ] #35: markdown links open in a new tab (`target="_blank" rel="noopener noreferrer"`), a regex pass in `R/mc_md_render.R`.
- [ ] #42: each inline table style declaration is written once, not twice. Same file, same kind of pass as #35.
- [ ] #10: integration tests that send from a `.md` file via `path =` and with `sig = TRUE`. These are the real-Gmail check for #35, #42 and the inline images, so they run before merge (`MC_RUN_INTEGRATION=true`).

What ties them together: each changes the HTML body mc builds, and #10 verifies it in a real inbox.

**Start from** the existing branch `43-inline-images`; PR #44 becomes this move's pull request, its body extended with `Fixes #35`, `Fixes #42`, `Fixes #10`. It must land before move 3, which also edits `R/mc_deliver.R` and `R/mc_draft.R`.

**After merge, next move:** #51 (move 3 of 3).

---

**If we do it:** HTML emails built with mc can show images in the body, not only as attachments.
**If we never do:** body images have to be remote URLs, which many clients block until the reader allows them, or the message has to be built outside mc.

## Problem

`mc_deliver()` builds a `gm_html_body()` plus ordinary attachments. There is no way to reference an image from the HTML body, so `<img src="cid:...">` has nothing to point at. Inline `data:` URIs are stripped by Gmail. The only option inside mc today is a remote `https://` image, which Gmail proxies and other clients often block by default.

## Proposed Solution

Add an `inline_images` argument to `mc_send()`, `mc_draft()` and the `mc_md_*` variants: a named character vector, name = Content-ID, value = file path.

```r
mc_send(
  html = '<p><img src="cid:card" width="600" alt="..."></p>',
  inline_images = c(card = "fig/card.png"),
  to = "someone@example.com", subject = "Hello"
)
```

gmailr 3.0.0 already supports this at the part level: `gmailr:::gm_attach_part(id = )` sets the `Content-Id` header, and `disposition` passes through `...`. So `mc_deliver()` can add each image with `disposition = "inline"` and `id = <name>`, next to the existing attachments loop. It should:

- check each path exists and each name is a valid Content-ID token
- warn when a name is never referenced as `cid:<name>` in the HTML, and error when the HTML references a `cid:` with no matching image
- keep images when `to_self = TRUE` (that is how the rendering gets tested)
- pass through the scheduled-send path (`schedule_args`)

Check whether Gmail renders inline parts inside gmailr's `multipart/mixed` wrapper or needs `multipart/related`. If it needs `related`, that is a gmailr limitation to note, and possibly an upstream issue.

## Acceptance

- [ ] `mc_send(to_self = TRUE, inline_images = ...)` shows the image in the body in Gmail web and Apple Mail, and the image is not also listed as a separate attachment (or that is documented if unavoidable)
- [ ] Tests for the argument checks and for the MIME structure (part has `Content-Id` and `inline` disposition), without sending
- [ ] Works through `mc_draft()`, `mc_md_send()` and scheduled sends



## Merge of main (2026-11-05)

- Conflicts: `DESCRIPTION` (branch added `mime`, main added `rappdirs`: kept both) and
  `tests/testthat/test-mc_send.R` (the unmocked-send test, fixed on both sides; took main's).
- After the merge, `devtools::test()`: 501 pass, 1 fail. The failure is main's own guard
  `every scheduled-send field survives the JSON round trip mc_send() checks`
  (`test-mc_schedule.R`), which walks every name in `mc_deliver()`'s `schedule_args` and finds
  `inline_images` with no case. It is the Phase 1 defect, caught by #47's guard: the guard
  fires on the field set before the round trip itself is exercised.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Plan review (review-plan.md)

Plan agent, background, 2026-11-05; it reported after Phases 1-4 had landed. Acted on in Phase 4b. Notes:

- Its correction to the plan's Context holds: the old `cid:` regex fired only on a token character
  right after the colon (`Placid:calm`), not on `acid: strong`. The landed test used the firing form.
- Decided, not in #35 or the gate: `mailto:` links get `target="_blank"` too. Gmail opens a compose
  window either way; other clients that honour it open the mail app instead of navigating away.
- Phase 5's integration tests read back the MIME mc sent: they prove the md + signature + MIME
  pipeline end to end, not how a client renders it. Gmail web opens every link in a new tab on its
  own, so #35's change shows only in other clients.
- Callr: the Phase 1 test mocks `schedule_send`, so it proves `mc_deliver()` hands callr a named,
  absolute vector; `r_bg` passes R objects through RDS, which keeps names. Not exercised live.
- Deferred to the chip result: dropping `name =`/`filename =` on the inline part, which some
  clients use to decide on a chip; needs the owner's word (gate decision 3 says no workaround).

## Live launchd scheduled send with an inline image (2026-11-05)

Installed the branch (`R CMD INSTALL .`, launchd runs the installed package), scheduled from the
scratchpad with a relative image path, `send_at = 2`, `to_self = TRUE`. The args JSON held
`{"card": "<absolute path>"}`. Send log: SCHEDULED 07:09:52Z, STARTED 07:11:52Z, SENT 07:11:54Z;
plist and JSON removed. Gmail stored `text/html` + `image/png` with `Content-Id: <card>` and
`Content-Disposition: inline; filename=sched_card.png`.

## Lint

Branch vs `origin/main` worktree, per file / linter / source line: the only added lints were in
`tests/testthat/test-inline_images.R` (semicolons, one-line braces, hanging indent); fixed. The
standing count elsewhere is main's.

## Chip check (Phase 6), 2026-11-05

Owner looked at the to-self messages ("mc chip check", the scheduled one, and probe B without a
filename) in Gmail web and on their phone: **no attachment card on any of them**. The issue's
acceptance ("not also listed as a separate attachment") is met inside gmailr's `multipart/mixed`;
gate decision 3 (document + upstream draft) is not needed. `name =`/`filename =` stay on the part.

## Code-check round 1 (review-round1.md)

Four fragile findings, all reproduced by the reviewer and fixed:
- Preview `file://` URL not percent-encoded, and Windows backslashes read as regex escapes in the
  replacement: new `file_url()` (forward slashes, per-segment `URLencode(reserved = TRUE)`).
- Three findings were one mechanism: **attributes read by a regex over the whole tag text** (or the
  whole body), so text inside a quoted value or a code span was read as an attribute. Enumerated
  every attribute reader in the branch: `style_tag()` (style detection and unquoted-style quoting),
  `inject_link_target()` (`has()` and the fragment check), `check_inline_images()` (the `cid:`
  scan). All now go through `tag_attrs()`, a left-to-right tokenizer in which each quoted value is
  consumed by its own attribute; the `cid:` scan reads only start tags (`cid_refs()`).
- Integration assertion `expect_length(gregexpr(...)[[1]], 1)` passed on zero matches: now counts.

## Test message to the owner's personal inbox (2026-11-05, on request)

Sent `mc_send(path = <md>, sig = TRUE, inline_images = c(card = ...))` to the owner's personal
address, BCC al@, and read it in Chrome (Gmail web): header stripped, link present, every cell
bordered including the right-aligned column, image in the body, signature, **no attachment
card**. Gmail web's DOM shows the link without our `target` (Gmail rewrites links and opens them
in a new tab itself); the attribute is in the sent MIME, as the integration test reads back.
