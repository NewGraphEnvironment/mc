# Create a Gmail draft from a markdown file

Creates a draft for review. Nothing passed to this function sends — to
deliver a message, call
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

## Usage

``` r
mc_draft(
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
  ...
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

  Logical. If `TRUE`, address the draft to `from` and drop `cc`, `bcc`
  and `thread_id`. Default `FALSE`.

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

## Value

The Gmail thread ID of the resulting draft, invisibly. May be `NULL` if
the gmailr response did not include one.

## Details

[`gmailr::gm_create_draft()`](https://gmailr.r-lib.org/reference/gm_create_draft.html)
does not accept a `thread_id`, so drafts always land outside the
conversation. Supplying `thread_id` warns. Either move the draft into
the thread from the Gmail UI before sending, or use
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
to deliver straight into the thread.

`send_at` and `scheduler` are not accepted here. A scheduled message is
by definition one that gets sent, so scheduling lives on
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

## See also

[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
to send,
[`mc_md_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_md_draft.md)
to draft from frontmatter.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_draft("communications/newsletter.md",
         to = "someone@example.com",
         subject = "Spring newsletter")

# Draft addressed to yourself, to check the rendering
mc_draft("communications/newsletter.md",
         to = "someone@example.com",
         subject = "Spring newsletter",
         to_self = TRUE)
} # }
```
