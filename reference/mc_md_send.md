# Send or draft an email from a markdown file with YAML frontmatter

One-file workflow: reads metadata (`to`, `subject`, optional `cc`,
`bcc`, `thread_id`, `attachments`, `labels`, `from`) from the YAML
frontmatter at the top of a markdown draft and dispatches to
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
Lets callers keep each logical email in a single `.md` file instead of
splitting subject, body, and recipients across a paired `.R` script.

## Usage

``` r
mc_md_send(path, draft = TRUE, test = FALSE, override = list())
```

## Arguments

- path:

  Path to the markdown draft (with YAML frontmatter).

- draft:

  Logical. If `TRUE` (default), create a Gmail draft.

- test:

  Logical. Test mode — sends to self, strips cc/thread_id.

- override:

  Named list of arguments to override frontmatter values at call time
  (e.g. `list(draft = FALSE)` to send). Overrides merge **after**
  frontmatter, so `override` wins.

## Value

Invisibly returns whatever
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
returns.

## Details

Required frontmatter fields: `to`, `subject`. Missing either triggers an
error that names the file.

## Examples

``` r
if (FALSE) { # \dontrun{
# Draft from a frontmattered .md
mc_md_send("communications/20260413_cindy_newsletter_draft.md")

# Send for real, overriding the default draft = TRUE
mc_md_send(
  "communications/20260413_cindy_newsletter_draft.md",
  override = list(draft = FALSE)
)
} # }
```
