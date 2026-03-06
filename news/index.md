# Changelog

## mc 0.2.1

- Add `drafts` parameter to
  [`mc_thread_read()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_read.md)
  — includes draft messages with a `status` column (`"sent"` /
  `"draft"`).

## mc 0.2.0

- Add `attachments` parameter to
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  for file attachments.
- Remove hardcoded fallback email from `default_from()` — now errors if
  `options(mc.from)` and `MC_FROM` env var are both unset.
- Update CLAUDE.md with latest soul conventions.

## mc 0.1.0

- First stable release: compose, draft, and send emails from markdown
  via Gmail API.
- Core functions:
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md),
  [`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md),
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md),
  [`mc_scroll()`](https://newgraphenvironment.github.io/mc/reference/mc_scroll.md),
  [`mc_sig()`](https://newgraphenvironment.github.io/mc/reference/mc_sig.md).
- Thread support:
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md),
  [`mc_thread_read()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_read.md).
- Scheduled send with `send_at` and macOS `caffeinate` integration.
- Test mode redirects to sender for safe previewing.
