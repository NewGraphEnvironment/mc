# mc 0.2.0

* Add `attachments` parameter to `mc_send()` for file attachments.
* Remove hardcoded fallback email from `default_from()` — now errors if
  `options(mc.from)` and `MC_FROM` env var are both unset.
* Update CLAUDE.md with latest soul conventions.

# mc 0.1.0

* First stable release: compose, draft, and send emails from markdown via Gmail API.
* Core functions: `mc_send()`, `mc_compose()`, `mc_md_render()`, `mc_scroll()`, `mc_sig()`.
* Thread support: `mc_thread_find()`, `mc_thread_read()`.
* Scheduled send with `send_at` and macOS `caffeinate` integration.
* Test mode redirects to sender for safe previewing.
