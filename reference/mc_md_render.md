# Render a markdown draft to HTML email body

Reads a markdown file, strips everything above the first `---` separator
(header metadata), converts the remaining markdown to HTML, inlines
table styles for Gmail compatibility, and appends the New Graph
signature.

## Usage

``` r
mc_md_render(path, sig = TRUE, sig_path = NULL)
```

## Arguments

- path:

  Path to the markdown draft file.

- sig:

  Logical. Append a signature? Default `TRUE`.

- sig_path:

  Path to a custom signature HTML file. Default `NULL` uses the bundled
  New Graph signature. Ignored when `sig = FALSE`.

## Value

A character string of HTML ready for
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

## Details

Gmail strips `<style>` blocks from HTML emails. This function adds
inline styles to `<table>`, `<th>`, and `<td>` elements so tables render
correctly.

The markdown file should follow the compost template format:

    # Email to Recipient - Topic

    **Subject:** ...

    **To:** ...

    ---

    Hi Name,

    Body text here.

Everything above and including the `---` line is stripped. Everything
below is converted to HTML.

## Examples

``` r
if (FALSE) { # \dontrun{
html <- mc_md_render("communications/20260222_brandon_cottonwood_draft.md")
cat(html)
} # }
```
