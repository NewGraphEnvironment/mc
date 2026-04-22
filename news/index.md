# Changelog

## mc 0.2.7

- Add
  [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  — adds and/or removes labels on a Gmail thread in one call. Accepts
  user label names or Gmail system labels (INBOX, STARRED, UNREAD,
  IMPORTANT, TRASH, SPAM, SENT, DRAFT), so the same verb covers archive
  (`remove = "INBOX"`), star (`add = "STARRED"`), trash, mark-read, and
  project-label workflows
  ([\#28](https://github.com/NewGraphEnvironment/mc/issues/28)).
- Bypasses a body-encoding bug in
  [`gmailr::gm_modify_thread()`](https://gmailr.r-lib.org/reference/gm_modify_thread.html)
  (3.0.0) by POSTing directly to `users.threads.modify`. `httr` added to
  Imports.

## mc 0.2.6

- Startup quote ritual:
  [`library(mc)`](https://github.com/NewGraphEnvironment/mc) prints a
  random fact-checked quote from 25 voices on attach. Italic quote, grey
  attribution, clickable blue `source` hyperlink. Suppress via
  `options(mc.quote_show_source = FALSE)`.
- 99 shipped entries from MLK, JFK, Bob Marley, Kurt Cobain, Chris
  Cornell, Robert Plant, James Hetfield, Tupac, Eminem, Ice-T, Ice Cube,
  RZA, ODB, Method Man, DJ Premier, Vince Staples, Logic, Mike Tyson,
  Jim Carrey, John Candy, Ronny Chieng, Jon Stewart, Stephen King,
  Quentin Tarantino, Paul Thomas Anderson.
- Curated via the soul `/quotes-enable` skill: parallel research agents,
  independent fact-check pass, user review.
- `cli` added to Imports for OSC 8 hyperlinks and styling in `R/zzz.R`.

## mc 0.2.5

- [`mc_preview()`](https://newgraphenvironment.github.io/mc/reference/mc_preview.md)
  now accepts a `.md` path in addition to an HTML string. When given a
  path, renders the frontmatter envelope (To / Cc / Subject / Thread /
  Attach) as a header above the body so recipient or subject mistakes
  are visible locally
  ([\#25](https://github.com/NewGraphEnvironment/mc/issues/25)).

## mc 0.2.4

- Add YAML frontmatter support for one-file email drafts
  ([\#23](https://github.com/NewGraphEnvironment/mc/issues/23)).
- Add
  [`mc_md_meta()`](https://newgraphenvironment.github.io/mc/reference/mc_md_meta.md)
  to read frontmatter as a named list.
- Add
  [`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
  to dispatch to
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  from frontmatter, with an `override` arg for call-time tweaks.
- Add
  [`mc_md_index()`](https://newgraphenvironment.github.io/mc/reference/mc_md_index.md)
  to scan a directory tree of drafts and return a searchable dataframe
  (`path`, `date`, `to`, `cc`, `subject`, `thread_id`,
  `has_attachments`).

## mc 0.2.3

- [`mc_preview()`](https://newgraphenvironment.github.io/mc/reference/mc_preview.md)
  now writes to a stable path under `tools::R_user_dir("mc","cache")`
  instead of [`tempfile()`](https://rdrr.io/r/base/tempfile.html) so the
  preview survives non-interactive `Rscript` sessions. `open` now
  defaults to `TRUE` and `path` is configurable
  ([\#22](https://github.com/NewGraphEnvironment/mc/issues/22)).

## mc 0.2.2

- Add
  [`mc_message_find()`](https://newgraphenvironment.github.io/mc/reference/mc_message_find.md)
  for message-level Gmail search.
- Add
  [`mc_thread_body_latest()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_body_latest.md)
  — latest thread reply with quoted history stripped.
- Add
  [`mc_preview()`](https://newgraphenvironment.github.io/mc/reference/mc_preview.md)
  — preview composed HTML in a browser before sending.
- Add `after` / `before` date filters to
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md).

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
