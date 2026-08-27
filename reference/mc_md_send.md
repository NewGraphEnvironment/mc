# Send an email from a markdown file with YAML frontmatter

One-file workflow: reads metadata (`to`, `subject`, optional `cc`,
`bcc`, `thread_id`, `attachments`, `labels`, `from`) from the YAML
frontmatter at the top of a markdown draft and dispatches to
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
Lets callers keep each logical email in a single `.md` file instead of
splitting subject, body, and recipients across a paired `.R` script.

## Usage

``` r
mc_md_send(path, to_self = FALSE, override = list())
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
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
returns.

## Details

Sends. To produce a Gmail draft for review instead, use
[`mc_md_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_md_draft.md).

Required frontmatter fields: `to`, `subject`. Missing either triggers an
error that names the file.

## See also

[`mc_md_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_md_draft.md)
to draft from frontmatter,
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
for the argument-driven form.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_md_send("communications/20260413_cindy_newsletter_draft.md")

# Check the rendering in a real inbox without involving anyone else
mc_md_send("communications/20260413_cindy_newsletter_draft.md",
           to_self = TRUE)
} # }
```
