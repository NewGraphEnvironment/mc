# Preview composed HTML in a browser before sending

Writes the output of
[`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md)
(or any HTML string) to a temp file and opens it in the default browser.
Catches markdown rendering issues (mis-nested links, stray backticks,
unintended list formatting, signature layout) locally before creating a
Gmail draft.

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

  A character string containing HTML, typically from
  [`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md).

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

## Examples

``` r
if (FALSE) { # \dontrun{
html <- mc_compose("communications/project/draft.md")
mc_preview(html)
} # }
```
