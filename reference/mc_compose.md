# Compose an HTML email from mixed content

Combines markdown files, HTML strings, and kable/kableExtra table
objects into a single HTML email body. Use this when you need
R-generated tables or other dynamic content mixed with prose.

## Usage

``` r
mc_compose(..., sig = TRUE, sig_path = NULL)
```

## Arguments

- ...:

  Parts to compose, in order. Each can be:

  Markdown file path

  :   A `.md` file path. The header above `---` is stripped (if present)
      and the body is converted to HTML.

  HTML string

  :   A character string of raw HTML, passed through as-is.

  kable/kableExtra object

  :   Output from
      [`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) or
      kableExtra functions. Converted to character automatically.

- sig:

  Logical. Append signature? Default `TRUE`.

- sig_path:

  Path to a custom signature HTML file. Default `NULL`.

## Value

A character string of HTML ready for the `html` argument of
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

## Details

For tables that look good in email:

- Use [`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) for
  clean, simple tables

- Use
  [`kableExtra::row_spec()`](https://rdrr.io/pkg/kableExtra/man/row_spec.html)
  and
  [`kableExtra::column_spec()`](https://rdrr.io/pkg/kableExtra/man/column_spec.html)
  for inline styling (colors, bold, backgrounds)

- Avoid `bootstrap_options` like `"striped"` — the CSS classes are
  stripped by Gmail

- Wrap large tables in
  [`mc_scroll()`](https://newgraphenvironment.github.io/mc/reference/mc_scroll.md)
  for horizontal/vertical scrolling

`mc_compose()` automatically adds border and padding inline styles to
all `<table>`, `<th>`, and `<td>` elements for Gmail compatibility.

## Examples

``` r
if (FALSE) { # \dontrun{
# Prose + table + more prose
df <- data.frame(Site = c("Nechako", "Mackenzie"), Plugs = c(4000, 3000))

body <- mc_compose(
  "communications/intro.md",
  knitr::kable(df, format = "html"),
  "communications/closing.md"
)
mc_send(html = body, to = "someone@example.com", subject = "Update")

# Inline markdown (no file needed)
body <- mc_compose(
  "<p>Hi Brandon,</p>",
  knitr::kable(df, format = "html"),
  "<p>Let me know if this looks right.</p>"
)
} # }
```
