# Inline images in Gmail from gmailr's MIME

**Verified:** 2026-11-05 · **Issues:** #43 · **Produced by:** to-self sends from branch
`43-inline-images` (gmailr 3.0.0), read back through the Gmail API and looked at by a person;
record in `planning/archive/2026-11-issue-43-email-body-inline-images/findings.md`.

**Inline parts inside gmailr's `multipart/mixed` render in the body, with no attachment card.**
gmailr builds every message as `multipart/mixed` and cannot build `multipart/related`, the
structure RFC 2387 names for HTML with embedded images. It is not needed for Gmail: a part added
with `gmailr::gm_attach_part(id = <cid>, disposition = "inline")` and referenced as
`<img src="cid:<cid>">` shows in the body and is not listed as an attachment.

- **Where checked:** Gmail web and the Gmail app on a phone. Apple Mail on the desktop was not
  named in the check.
- **Messages:** three to-self messages, one of them fired by a launchd scheduled send, and one
  message to a second Gmail inbox. Gmail stored each as `text/html` + `image/png` with
  `Content-Id: <card>` and `Content-Disposition: inline`.
- **`filename` makes no difference:** a probe with no `name`/`filename` on the part looked the
  same as one with them.
- **Gmail web opens every link in a new tab on its own.** It rewrites message links in its page,
  so mc's `target="_blank"` cannot be seen there. The attribute is in the sent MIME and matters in
  clients that honour it.
