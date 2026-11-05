# Build and deliver a message (internal)

Shared implementation behind
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
and
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
Renders the body, builds the MIME message, and either creates a Gmail
draft or sends, according to `.draft`.

## Usage

``` r
mc_deliver(
  path = NULL,
  to,
  subject,
  cc = NULL,
  bcc = NULL,
  from = default_from(),
  thread_id = NULL,
  .draft,
  to_self = FALSE,
  sig = TRUE,
  sig_path = NULL,
  attachments = NULL,
  inline_images = NULL,
  labels = NULL,
  labels_create = TRUE,
  html = NULL,
  send_at = NULL,
  scheduler = NULL
)
```

## Arguments

- path:

  Path to the markdown draft file. Passed to
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md).

- to:

  Recipient email address (character string or vector).

- subject:

  Email subject line.

- cc:

  Optional CC recipients (character vector). Default `NULL`.

- bcc:

  Optional BCC recipients (character vector). Default `NULL`.

- from:

  Sender address. Default uses `getOption("mc.from")`, then the
  `MC_FROM` environment variable. Errors if neither is set.

- thread_id:

  Gmail thread ID to reply into. Default `NULL` (new thread). Use
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md)
  to look up thread IDs.

- .draft:

  Logical. `TRUE` creates a Gmail draft, `FALSE` sends. Supplied by the
  wrapper, never by the caller.

- to_self:

  Logical. If `TRUE`, override `to` with `from` and drop `cc`, `bcc` and
  `thread_id`, so the message reaches nobody but the sender. Default
  `FALSE`. This caps who receives the message; it does not stop the
  send. Use
  [`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
  if you do not want a message delivered at all.

- sig:

  Logical. Append signature? Passed to
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md).
  Default `TRUE`.

- sig_path:

  Path to a custom signature HTML file. Default `NULL` uses the bundled
  New Graph signature. Passed to
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md).
  Ignored when `sig = FALSE` or when `html` is provided.

- attachments:

  Optional character vector of file paths to attach. Each file is
  attached via
  [`gmailr::gm_attach_file()`](https://gmailr.r-lib.org/reference/gm_mime.html).
  Default `NULL`. A scheduled send reads the files when it fires, so
  they must still exist then (not a
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html) from a session
  that has ended).

- inline_images:

  Optional named character vector of image paths to show in the body:
  each name is a Content-ID the HTML references as
  `<img src="cid:name">`, or in markdown as `![alt](cid:name)`. Names
  use letters, digits and `. _ @ -`. A `cid:` reference (in `src`,
  `background` or a CSS
  [`url()`](https://rdrr.io/r/base/connections.html)) with no matching
  image is an error; an image the HTML never references is a warning.
  Kept when `to_self = TRUE`. In YAML frontmatter, give a mapping
  (`inline_images:` then ` card: fig/card.png`), not a list. Paths
  resolve against the working directory, and a scheduled send reads the
  files when it fires, as for `attachments`.

- labels:

  Optional character vector of Gmail label names to apply to the
  resulting thread. Applied via
  [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  after a successful send.

- labels_create:

  Logical. When `TRUE` (default), missing user labels in `labels` are
  auto-created via
  [`mc_label_ensure()`](https://newgraphenvironment.github.io/mc/reference/mc_label_ensure.md).

- html:

  Optional pre-rendered HTML body. If provided, `path` is ignored and
  this HTML is used directly.

- send_at:

  Schedule the email for later. Either a `POSIXct` datetime or a numeric
  number of minutes from now. Default `NULL` (send now). Scheduling is
  inherently a send, which is why it lives here and not on
  [`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md).

- scheduler:

  Backend for scheduled send. One of `"auto"` (OS-native: `launchd` on
  macOS, `at` on Linux), `"callr"`, `"launchd"`, or `"at"`. Default
  `NULL` uses `"auto"` on macOS and Linux, where the OS owns the job and
  it survives the R session exiting, and `"callr"` elsewhere, with a
  warning that its send can be dropped. An explicit `"auto"` errors on a
  platform with no OS-native backend. Ignored when `send_at` is `NULL`.

## Value

Gmail thread ID, invisibly.

## Details

Not exported. The exported wrappers each fix `.draft`, which is what
makes "nothing passed to
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
can send" true by construction rather than by convention (#39).
