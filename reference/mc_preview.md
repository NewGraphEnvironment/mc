# Preview composed HTML in a browser before sending

Writes the output of
[`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md)
(or any HTML string) to a temp file and opens it in the default browser.
Catches markdown rendering issues (mis-nested links, stray backticks,
unintended list formatting, signature layout) locally before creating a
Gmail draft.

## Usage

``` r
mc_preview(html, open = interactive())
```

## Arguments

- html:

  A character string containing HTML, typically from
  [`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md).

- open:

  Logical. If `TRUE` (default in interactive sessions), open the file
  with [`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html).
  When `FALSE`, only write the file.

## Value

The tempfile path, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
html <- mc_compose("communications/project/draft.md")
mc_preview(html)
} # }
```
