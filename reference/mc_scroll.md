# Wrap a table in a scrollable container for email

Wraps HTML table output in a `<div>` with `overflow` CSS so large tables
scroll horizontally, vertically, or both in Gmail.

## Usage

``` r
mc_scroll(table, direction = "both", max_height = "400px")
```

## Arguments

- table:

  A kable/kableExtra object or a character string of HTML.

- direction:

  Scroll direction: `"wide"` (horizontal), `"long"` (vertical), or
  `"both"`. Default `"both"`.

- max_height:

  Maximum height before vertical scrolling kicks in. Default `"400px"`.
  Ignored when `direction = "wide"`.

## Value

A character string of HTML with the table inside a scrollable div.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- data.frame(x = 1:50, y = rnorm(50))

# Vertical scroll
mc_scroll(knitr::kable(df, format = "html"), direction = "long")

# Horizontal scroll
mc_scroll(knitr::kable(wide_df, format = "html"), direction = "wide")

# Use with mc_compose
body <- mc_compose(
  "<p>Here's the data:</p>",
  mc_scroll(knitr::kable(df, format = "html"))
)
} # }
```
