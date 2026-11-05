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
