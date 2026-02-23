# Tables in Emails

## The problem

[`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md)
converts a single markdown file to HTML. But what if you need an
R-generated table in the middle of your email? You can’t put R code in a
plain `.md` file.

## mc_compose()

`mc_compose()` takes any mix of markdown files, HTML strings, and kable
objects and stitches them into one email body.

``` r
library(mc)

df <- data.frame(
  Site = c("Nechako", "Mackenzie", "Skeena"),
  Plugs = c(4000, 3000, 3000)
)

body <- mc_compose(
  "communications/intro.md",
  knitr::kable(df, format = "html"),
  "<p>Let me know if the numbers look right.</p>"
)

mc_send(html = body,
        to = "brandon@example.com",
        subject = "Planting site summary")
```

Each argument is resolved in order:

- **`.md` file** — header above `---` is stripped, body converted to
  HTML
- **kable/kableExtra object** — converted to HTML via
  [`as.character()`](https://rdrr.io/r/base/character.html)
- **HTML string** — passed through as-is

All `<table>`, `<th>`, and `<td>` elements get border and padding styles
injected automatically for Gmail compatibility.

## Simple table with knitr::kable

The most reliable option. Clean HTML, minimal styling, works everywhere.

``` r
df <- data.frame(
  Site = c("Nechako", "Mackenzie", "Skeena"),
  Plugs = c(4000, 3000, 3000),
  Status = c("Confirmed", "Pending", "Pending")
)

knitr::kable(df, format = "html")
```

| Site      | Plugs | Status    |
|:----------|------:|:----------|
| Nechako   |  4000 | Confirmed |
| Mackenzie |  3000 | Pending   |
| Skeena    |  3000 | Pending   |

`mc_compose()` adds border and padding inline styles to every cell.

## Styled table with kableExtra

For colors, bold headers, or highlighted rows, use
[`kableExtra::row_spec()`](https://rdrr.io/pkg/kableExtra/man/row_spec.html)
and
[`kableExtra::column_spec()`](https://rdrr.io/pkg/kableExtra/man/column_spec.html).
These add **inline styles** that survive Gmail’s CSS stripping.

``` r
library(kableExtra)

kbl(df, format = "html") |>
  kable_styling(full_width = FALSE) |>
  row_spec(0, bold = TRUE, background = "#f5f5f5") |>
  column_spec(1, bold = TRUE) |>
  column_spec(2, color = "#2c7bb6")
```

| Site      | Plugs | Status    |
|:----------|------:|:----------|
| Nechako   |  4000 | Confirmed |
| Mackenzie |  3000 | Pending   |
| Skeena    |  3000 | Pending   |

**Avoid** `bootstrap_options` like `"striped"` or `"hover"` — these rely
on CSS classes in a `<style>` block that Gmail strips. Use
[`row_spec()`](https://rdrr.io/pkg/kableExtra/man/row_spec.html) with
explicit `background` colors instead:

``` r
# Manual striping that works in Gmail
kbl(df, format = "html") |>
  kable_styling(full_width = FALSE) |>
  row_spec(0, bold = TRUE, background = "#f5f5f5") |>
  row_spec(seq(2, nrow(df), 2), background = "#f9f9f9")
```

## No scrolling tables

Gmail strips `overflow` CSS and JavaScript. Scrolling tables are not
possible in email. If your table is too wide, consider:

- Fewer columns — move detail to an attachment or linked report
- Abbreviate headers
- Split into multiple smaller tables

## Full workflow

``` r
library(mc)

# Authenticate once per session
mc_auth()

# Build the email
sites <- data.frame(
  Site = c("Nechako", "Mackenzie", "Skeena"),
  Plugs = c(4000, 3000, 3000),
  Season = c("Fall 2026", "Fall 2026", "Fall 2026")
)

body <- mc_compose(
  "<p>Hi Brandon,</p>
   <p>Here's the current planting plan:</p>",

  kableExtra::kbl(sites, format = "html") |>
    kableExtra::kable_styling(full_width = FALSE) |>
    kableExtra::row_spec(0, bold = TRUE, background = "#f5f5f5"),

  "<p>Total: 10,000 plugs across three sites.</p>
   <p>Does this match what the nursery has available?</p>"
)

# Draft first, send when ready
mc_send(html = body,
        to = "brandon@example.com",
        subject = "2026 planting plan — cottonwood plugs")
```
