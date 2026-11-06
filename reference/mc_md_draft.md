# Create a Gmail draft from a markdown file with YAML frontmatter

Reads metadata (`to`, `subject`, optional `cc`, `bcc`, `thread_id`,
`draft_id`, `attachments`, `inline_images`, `labels`, `from`) from the
YAML frontmatter at the top of a markdown draft and dispatches to
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md).

## Usage

``` r
mc_md_draft(path, to_self = FALSE, override = list())
```

## Arguments

- path:

  Path to the markdown draft (with YAML frontmatter).

- to_self:

  Logical. If `TRUE`, address the message to the sender and drop `cc`,
  `bcc` and `thread_id`, so it reaches nobody else. Default `FALSE`.
  Caps the recipients; does not stop the send.

- override:

  Named list of arguments to override frontmatter values at call time
  (e.g. `list(subject = "New subject")`). Overrides merge **after**
  frontmatter, so `override` wins.

## Value

Invisibly returns what
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
returns: a list with `draft_id`, `thread_id` and `message_id`.

## Details

Drafts only. Nothing passed here sends — use
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
to deliver.

Required frontmatter fields: `to`, `subject`. Missing either triggers an
error that names the file.

The file keeps track of its own draft. When a draft is created, its id
is written into the frontmatter as `draft_id:` (that one line is added
or changed; the rest of the file is left as it was). Running the same
file again replaces that draft in place, and only that draft. If the
draft has since been sent or deleted, a new one is created and its id
written in. Delete the `draft_id:` line to start a fresh draft.
Replacing overwrites the draft as it stands in Gmail, including any
edits made there.

With `to_self = TRUE` the draft is a separate test copy: the file's
`draft_id` is not used and the copy's id is not recorded, so the tracked
draft is left alone.
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
ignores `draft_id`.

A `thread_id` in the frontmatter creates the draft in that conversation.
See
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md).

## See also

[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
to send,
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
for the argument-driven form.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_md_draft("communications/20260413_cindy_newsletter_draft.md")
} # }
```
