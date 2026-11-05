# Send an email from a markdown file

Sends immediately. To produce a Gmail draft for review instead, use
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md).

## Usage

``` r
mc_send(
  path = NULL,
  to,
  subject,
  cc = NULL,
  bcc = NULL,
  from = default_from(),
  thread_id = NULL,
  to_self = FALSE,
  sig = TRUE,
  sig_path = NULL,
  attachments = NULL,
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
  Default `NULL`.

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

The Gmail thread ID of the sent message, invisibly. When `send_at` is
set, returns a backend-specific scheduler handle invisibly instead.

## Details

The verb lives in the function name deliberately. An earlier API
selected send-vs-draft with a `draft` argument, which meant one
character separated a reversible act from an irreversible one — and did,
once, deliver a message to external recipients when a draft was
intended. There is no `draft` argument here; sending is named, not
configured (#39).

Authenticates automatically if no active Gmail session is detected.

## See also

[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
to create a draft,
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
to send from frontmatter.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_send("communications/newsletter.md",
        to = "someone@example.com",
        subject = "Spring newsletter")

# Check the rendering in a real inbox without involving anyone else
mc_send("communications/newsletter.md",
        to = "someone@example.com",
        subject = "Spring newsletter",
        to_self = TRUE)

# Reply into an existing thread
mc_send("communications/reply.md",
        to = "someone@example.com",
        subject = "Re: Spring newsletter",
        thread_id = "19c05f0a98188c91")
} # }
```
