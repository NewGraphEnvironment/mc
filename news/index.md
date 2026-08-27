# Changelog

## mc 0.3.0

### Breaking changes

- **[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  no longer drafts.** Delivery is split by function name:
  [`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
  can only create a Gmail draft and
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  can only send. The frontmatter pair splits the same way —
  [`mc_md_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_md_draft.md)
  and
  [`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md).
  The `draft` argument is gone from all of them, with no deprecated
  alias ([\#39](https://github.com/NewGraphEnvironment/mc/issues/39)).

  Previously a single boolean selected between a reversible act and an
  irreversible one, so one character separated them. That produced a
  real incident: a message reached nine external recipients when a draft
  was intended. Sending is now named rather than configured, and nothing
  passed to
  [`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
  can send.

- **`test` is renamed `to_self`.** The old name implied a dry run and
  never was one — it rewrites the recipients so the message reaches only
  the sender, but with `draft = FALSE` it still sent. `to_self` says
  what it does. Use
  [`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
  when you want nothing delivered.

- [`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
  rejects `send_at` and `scheduler` with an error naming
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
  A scheduled message is by definition one that gets sent.

- `override` in
  [`mc_md_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_md_draft.md)
  /
  [`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
  rejects `draft` and `test` keys, naming the replacement. `override` is
  a back door into the dispatch arguments, so removing the formals did
  not close the path on its own.

### Migration

``` r

mc_send(..., draft = TRUE)              # -> mc_draft(...)
mc_send(..., draft = FALSE)             # -> mc_send(...)
mc_send(..., draft = FALSE, test = TRUE)  # -> mc_send(..., to_self = TRUE)
mc_md_send(path)                        # -> mc_md_draft(path)
mc_md_send(path, override = list(draft = FALSE))  # -> mc_md_send(path)
```

Calls passing `draft` or `test` error rather than changing behaviour
silently.

## mc 0.2.10

- [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  gains a `scheduler` argument selecting the backend for scheduled sends
  — `"callr"` (default, for backward compatibility), `"auto"` (resolves
  to OS-native: `launchd` on macOS, `at` on Linux), or an explicit
  `"launchd"` / `"at"`. OS-native backends own their own job lifecycle
  independent of the originating R session — fixes the silent-drop
  failure mode where a
  [`callr::r_bg`](https://callr.r-lib.org/reference/r_bg.html) child got
  cleaned up when its parent `Rscript` invocation exited
  ([\#36](https://github.com/NewGraphEnvironment/mc/issues/36)).
- **Behavior change:** using `scheduler = "callr"` now emits a
  [`warning()`](https://rdrr.io/r/base/warning.html) flagging the
  unreliable lifecycle in some call contexts (`Rscript` one-shot,
  RStudio sessions that exit, CI). Steers users toward
  `scheduler = "auto"`. The default is still `"callr"` for back-compat —
  pass `scheduler = "auto"` (or set in YAML override) to silence the
  warning and use the OS-native backend.
- `send_at` now writes heartbeat log entries to `~/.mc/send_log.txt` so
  missed fires are auditable from the log alone: `SCHEDULED` at
  submission with the target time, `STARTED` at fire, plus the existing
  `SENT` / `SKIPPED` / `FAILED` entries. A `SCHEDULED` line with no
  follow-up `STARTED` means the bg process died before firing
  ([\#36](https://github.com/NewGraphEnvironment/mc/issues/36)).
- Internal: scheduled-send HTML is now pre-rendered before backend
  dispatch so the body travels with the serialized args — avoids
  fire-time filesystem dependency on the original draft and fixes a
  potential silent failure for `path`-based scheduled sends.
- Internal: new `R/mc_schedule.R` houses the dispatcher, backends, and
  the `run_scheduled_send` fire-time entry point used by the OS-native
  backends. Triple-colon access pattern matches existing internal
  helpers.
- Internal: launchd cleanup unlinks plist + args JSON without calling
  `launchctl unload` from inside the running job — `unload` SIGTERMs the
  job’s process group, killing the cleanup mid-flight (caught by live
  test). Stale `launchctl list` entry persists until next reboot but the
  dormant `StartCalendarInterval` (set to a single past minute) never
  re-fires.

## mc 0.2.9

- Add `mc_label_ensure(label_names)` — primitive that creates missing
  Gmail user labels and no-ops for existing ones. System labels (INBOX,
  STARRED, etc.) are skipped via case-insensitive match
  ([\#33](https://github.com/NewGraphEnvironment/mc/issues/33)).
- [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  gains `create_missing = FALSE` (opt-in). When `TRUE`, calls
  `mc_label_ensure(add)` before resolving names so new labels in `add`
  are auto-created. Default preserves the existing typo-guard behavior
  ([\#33](https://github.com/NewGraphEnvironment/mc/issues/33)).
- [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  gains `labels_create = TRUE` (default on). The YAML- driven workflow
  ([`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md))
  now creates new project tags on first use — no need to pre-create
  labels via
  [`gmailr::gm_create_label()`](https://gmailr.r-lib.org/reference/gm_create_label.html).
  Set `FALSE` for strict typo-guard. Threaded through scheduled-send
  recursion
  ([\#33](https://github.com/NewGraphEnvironment/mc/issues/33)).
- Internal: `resolve_label_names()` now matches system labels case-
  insensitively and normalizes returned IDs to uppercase, fixing a
  cross-function inconsistency where `mc_label_ensure` skipped `"inbox"`
  as system but `mc_thread_modify` then erred trying to resolve it. Side
  benefit: callers can pass mixed-case system labels (“Inbox”,
  “Starred”) and get correct resolution.

## mc 0.2.8

- [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  accepts a `labels` argument (character vector of Gmail label names)
  and applies them to the resulting thread via
  [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  on both the draft and sent paths. Drafts get tagged so they’re
  findable in Drafts under the project label and so the label rides
  through when the user sends from the Gmail UI (Gmail typically keeps
  the same thread). Unknown label names raise the existing
  [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  error listing available user labels
  ([\#31](https://github.com/NewGraphEnvironment/mc/issues/31)).
- [`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
  reads `labels:` from YAML frontmatter (character vector) and passes
  through to
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
  Project tags can live in the `.md` draft alongside `to`, `subject`,
  `cc`, `thread_id`, etc.
  ([\#31](https://github.com/NewGraphEnvironment/mc/issues/31)).
- [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  now returns the Gmail thread ID of the resulting draft or sent message
  invisibly (was `invisible(NULL)`). Lets callers chain follow-on
  operations like
  [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  cleanly ([\#31](https://github.com/NewGraphEnvironment/mc/issues/31)).

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
