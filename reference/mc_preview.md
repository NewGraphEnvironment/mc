# Preview composed HTML in a browser before sending

Writes composed HTML to a local file and opens it in the default browser
so markdown rendering issues (mis-nested links, stray backticks,
unintended list formatting, signature layout) can be caught before
creating a Gmail draft.

## Usage

``` r
mc_preview(
  html,
  path = file.path(tools::R_user_dir("mc", "cache"), "preview.html"),
  open = TRUE
)
```

## Arguments

- html:

  Either a character string of HTML (e.g. from
  [`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md))
  or a path to a `.md` draft file. A `.md` path is detected by the
  combination of `endsWith(x, ".md")` and `file.exists(x)`.

- path:

  File path to write the preview to. Defaults to a stable location under
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)
  (`mc/cache/preview.html`) so the file persists after the R session
  exits and can be opened manually.

- open:

  Logical. If `TRUE` (default), open the file with
  [`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html). When
  `FALSE`, only write the file.

## Value

The file path, invisibly.

## Details

Accepts either a raw HTML string or a path to a `.md` draft. When a
`.md` path is passed, the frontmatter envelope (To / Cc / Subject /
Thread / Attachments) is rendered above the body so recipient or subject
mistakes are visible too.

## Examples

``` r
if (FALSE) { # \dontrun{
# From raw HTML
html <- mc_compose("communications/project/draft.md")
mc_preview(html)

# Directly from a frontmattered .md — shows envelope above body
mc_preview("communications/20260413_cindy_newsletter_draft.md")
} # }
```
