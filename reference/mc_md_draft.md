# Create a Gmail draft from a markdown file with YAML frontmatter

Reads metadata (`to`, `subject`, optional `cc`, `bcc`, `thread_id`,
`attachments`, `labels`, `from`) from the YAML frontmatter at the top of
a markdown draft and dispatches to
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

Invisibly returns whatever
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
returns.

## Details

Drafts only. Nothing passed here sends — use
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md)
to deliver.

Required frontmatter fields: `to`, `subject`. Missing either triggers an
error that names the file.

A `thread_id` in the frontmatter warns:
[`gmailr::gm_create_draft()`](https://gmailr.r-lib.org/reference/gm_create_draft.html)
cannot thread a draft. See
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
