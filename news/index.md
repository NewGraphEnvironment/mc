# Changelog

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
