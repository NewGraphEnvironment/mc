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
  draft_id = NULL,
  to_self = FALSE,
  sig = TRUE,
  sig_path = NULL,
  attachments = NULL,
  inline_images = NULL,
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
  to look up thread IDs. The message answers the thread's latest
  message: it carries `In-Reply-To` and `References` headers naming it,
  so recipients' mail clients thread it too, and the subject gains a
  `Re: ` prefix unless it already has one. The thread is read first; if
  it cannot be read, nothing is sent.

- draft_id:

  `NULL` (default) to create a new draft, or the id of a draft to
  replace in place, as returned in `draft_id` by an earlier call. Only
  that draft changes, and it keeps its id. If Gmail does not know the id
  (the draft was sent or deleted, or the id is not a draft id), a
  warning is given and a new draft is created.

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

- ...:

  Not used. Present only so that passing `send_at` or `scheduler` errors
  with a pointer to
  [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
  rather than R's generic unused-argument error. Any other argument
  errors as unused.

## Value

A list, invisibly, with `draft_id` (pass it back as `draft_id` to
replace this draft), `thread_id` and `message_id`. `draft_id` stays the
same across replacements; `message_id` is the Gmail API id of the
draft's current message (not its `Message-ID` header) and changes on
each replacement. An element is `NULL` when Gmail's response did not
include it.

## Details

With `thread_id`, the draft is created in that conversation, ready to
review and send from the thread, and carries the reply headers described
in
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
Gmail decides whether a draft joins a thread; if it puts the draft
somewhere else, a warning says so.

mc never deletes a draft. To regenerate one (a re-rendered attachment,
an edited body), pass the `draft_id` it returned; nothing else in the
mailbox is touched. Replacing overwrites the draft as it stands,
including any edits made to it in Gmail. Pass the same `thread_id` and
`labels` as when the draft was made: a replacement without `thread_id`
takes the draft out of its thread, and labels not given again are
dropped.

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

# Replace that draft after editing the file: same draft, same id
d <- mc_draft("communications/newsletter.md",
              to = "someone@example.com",
              subject = "Spring newsletter")
mc_draft("communications/newsletter.md",
         to = "someone@example.com",
         subject = "Spring newsletter",
         draft_id = d$draft_id)

# Draft addressed to yourself, to check the rendering
mc_draft("communications/newsletter.md",
         to = "someone@example.com",
         subject = "Spring newsletter",
         to_self = TRUE)
} # }
```
