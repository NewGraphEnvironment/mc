# mc 0.2.7

* Add `mc_thread_modify()` — adds and/or removes labels on a Gmail thread
  in one call. Accepts user label names or Gmail system labels (INBOX,
  STARRED, UNREAD, IMPORTANT, TRASH, SPAM, SENT, DRAFT), so the same
  verb covers archive (`remove = "INBOX"`), star (`add = "STARRED"`),
  trash, mark-read, and project-label workflows (#28).
* Bypasses a body-encoding bug in `gmailr::gm_modify_thread()` (3.0.0)
  by POSTing directly to `users.threads.modify`. `httr` added to Imports.

# mc 0.2.6

- Startup quote ritual: `library(mc)` prints a random fact-checked quote from 25 voices on attach. Italic quote, grey attribution, clickable blue `source` hyperlink. Suppress via `options(mc.quote_show_source = FALSE)`.
- 99 shipped entries from MLK, JFK, Bob Marley, Kurt Cobain, Chris Cornell, Robert Plant, James Hetfield, Tupac, Eminem, Ice-T, Ice Cube, RZA, ODB, Method Man, DJ Premier, Vince Staples, Logic, Mike Tyson, Jim Carrey, John Candy, Ronny Chieng, Jon Stewart, Stephen King, Quentin Tarantino, Paul Thomas Anderson.
- Curated via the soul `/quotes-enable` skill: parallel research agents, independent fact-check pass, user review.
- `cli` added to Imports for OSC 8 hyperlinks and styling in `R/zzz.R`.

# mc 0.2.5

* `mc_preview()` now accepts a `.md` path in addition to an HTML string.
  When given a path, renders the frontmatter envelope (To / Cc / Subject
  / Thread / Attach) as a header above the body so recipient or subject
  mistakes are visible locally (#25).

# mc 0.2.4

* Add YAML frontmatter support for one-file email drafts (#23).
* Add `mc_md_meta()` to read frontmatter as a named list.
* Add `mc_md_send()` to dispatch to `mc_send()` from frontmatter, with
  an `override` arg for call-time tweaks.
* Add `mc_md_index()` to scan a directory tree of drafts and return a
  searchable dataframe (`path`, `date`, `to`, `cc`, `subject`,
  `thread_id`, `has_attachments`).

# mc 0.2.3

* `mc_preview()` now writes to a stable path under `tools::R_user_dir("mc","cache")`
  instead of `tempfile()` so the preview survives non-interactive `Rscript`
  sessions. `open` now defaults to `TRUE` and `path` is configurable (#22).

# mc 0.2.2

* Add `mc_message_find()` for message-level Gmail search.
* Add `mc_thread_body_latest()` — latest thread reply with quoted history stripped.
* Add `mc_preview()` — preview composed HTML in a browser before sending.
* Add `after` / `before` date filters to `mc_thread_find()`.

# mc 0.2.1

* Add `drafts` parameter to `mc_thread_read()` — includes draft messages
  with a `status` column (`"sent"` / `"draft"`).

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
