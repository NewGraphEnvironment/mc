# Tables in Emails

## The problem

[`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md)
converts a single markdown file to HTML. But what if you need an
R-generated table in the middle of your email? You can’t put R code in a
plain `.md` file.

## mc_compose()

[`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md)
takes any mix of markdown files, HTML strings, and kable objects and
stitches them into one email body.

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

[`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md)
adds border and padding inline styles to every cell.

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
kbl(df, format = "html") |>
  kable_styling(full_width = FALSE) |>
  row_spec(0, bold = TRUE, background = "#f5f5f5") |>
  row_spec(seq(2, nrow(df), 2), background = "#f9f9f9")
```

| Site      | Plugs | Status    |
|:----------|------:|:----------|
| Nechako   |  4000 | Confirmed |
| Mackenzie |  3000 | Pending   |
| Skeena    |  3000 | Pending   |

## Scrollable tables

Large tables can be wrapped in a scrollable `<div>` using
[`mc_scroll()`](https://newgraphenvironment.github.io/mc/reference/mc_scroll.md).
Gmail preserves the `overflow` CSS so these scroll in the email client.

### Wide table (horizontal scroll)

``` r
wide_df <- data.frame(
  Site = c("Nechako", "Mackenzie", "Skeena"),
  Plugs = c(4000, 3000, 3000),
  Season = c("Fall 2026", "Fall 2026", "Fall 2026"),
  Latitude = c(53.92, 55.34, 54.38),
  Longitude = c(-124.02, -122.97, -127.17),
  BEC_Zone = c("SBSdw3", "SBSmk1", "SBSdk"),
  Elevation_m = c(680, 700, 520),
  Stock = c("Local", "Transfer", "Transfer"),
  Nursery = c("PRT Vernon", "PRT Vernon", "PRT Vernon"),
  Crew = c("Alpine Reforestation", "TBD", "TBD"),
  Access = c("FSR 200", "FSR 440", "Morice West"),
  Prep = c("Complete", "Scheduled", "Not started"),
  Soil = c("Silty clay", "Sandy loam", "Clay loam"),
  Moisture = c("Subhygric", "Mesic", "Hygric"),
  Permit = c("Approved", "In review", "Not submitted")
)

cat(mc_scroll(knitr::kable(wide_df, format = "html"), direction = "wide"))
```

| Site      | Plugs | Season    | Latitude | Longitude | BEC_Zone | Elevation_m | Stock    | Nursery    | Crew                 | Access      | Prep        | Soil       | Moisture  | Permit        |
|:----------|------:|:----------|---------:|----------:|:---------|------------:|:---------|:-----------|:---------------------|:------------|:------------|:-----------|:----------|:--------------|
| Nechako   |  4000 | Fall 2026 |    53.92 |   -124.02 | SBSdw3   |         680 | Local    | PRT Vernon | Alpine Reforestation | FSR 200     | Complete    | Silty clay | Subhygric | Approved      |
| Mackenzie |  3000 | Fall 2026 |    55.34 |   -122.97 | SBSmk1   |         700 | Transfer | PRT Vernon | TBD                  | FSR 440     | Scheduled   | Sandy loam | Mesic     | In review     |
| Skeena    |  3000 | Fall 2026 |    54.38 |   -127.17 | SBSdk    |         520 | Transfer | PRT Vernon | TBD                  | Morice West | Not started | Clay loam  | Hygric    | Not submitted |

### Long table (vertical scroll)

``` r
set.seed(42)
sites <- c("Nechako", "Mackenzie", "Skeena", "Fraser", "Bulkley",
           "Stellako", "Endako", "Stuart", "Salmon", "Bowron")
long_df <- data.frame(
  Row = 1:50,
  Site = rep(sites, 5),
  Plugs = sample(100:500, 50, replace = TRUE),
  Survival_Pct = round(runif(50, 60, 98), 1),
  Height_cm = round(runif(50, 15, 85), 0)
)

cat(mc_scroll(knitr::kable(long_df, format = "html"), direction = "long"))
```

| Row | Site      | Plugs | Survival_Pct | Height_cm |
|----:|:----------|------:|-------------:|----------:|
|   1 | Nechako   |   148 |         92.3 |        53 |
|   2 | Mackenzie |   420 |         67.2 |        53 |
|   3 | Skeena    |   252 |         70.3 |        15 |
|   4 | Fraser    |   173 |         91.5 |        40 |
|   5 | Bulkley   |   327 |         86.3 |        58 |
|   6 | Stellako  |   245 |         69.1 |        73 |
|   7 | Endako    |   221 |         61.6 |        40 |
|   8 | Stuart    |   148 |         65.3 |        44 |
|   9 | Salmon    |   227 |         68.2 |        55 |
|  10 | Bowron    |   402 |         78.2 |        56 |
|  11 | Nechako   |   123 |         67.5 |        65 |
|  12 | Mackenzie |   426 |         87.3 |        43 |
|  13 | Skeena    |   455 |         60.3 |        79 |
|  14 | Fraser    |   188 |         74.3 |        82 |
|  15 | Bulkley   |   264 |         79.5 |        31 |
|  16 | Stellako  |   209 |         60.1 |        66 |
|  17 | Endako    |   119 |         82.1 |        78 |
|  18 | Stuart    |   469 |         66.0 |        57 |
|  19 | Salmon    |   466 |         73.6 |        59 |
|  20 | Bowron    |   486 |         84.5 |        81 |
|  21 | Nechako   |   396 |         89.5 |        75 |
|  22 | Mackenzie |   188 |         81.4 |        56 |
|  23 | Skeena    |   382 |         68.9 |        72 |
|  24 | Fraser    |   208 |         63.4 |        23 |
|  25 | Bulkley   |   104 |         63.3 |        69 |
|  26 | Stellako  |   311 |         71.6 |        59 |
|  27 | Endako    |   447 |         85.4 |        25 |
|  28 | Stuart    |   459 |         60.0 |        21 |
|  29 | Salmon    |   358 |         67.9 |        47 |
|  30 | Bowron    |   413 |         95.5 |        70 |
|  31 | Nechako   |   397 |         95.2 |        66 |
|  32 | Mackenzie |   123 |         87.9 |        72 |
|  33 | Skeena    |   257 |         72.7 |        27 |
|  34 | Fraser    |   398 |         79.6 |        81 |
|  35 | Bulkley   |   498 |         88.3 |        36 |
|  36 | Stellako  |   413 |         83.5 |        25 |
|  37 | Endako    |   235 |         83.8 |        65 |
|  38 | Stuart    |   391 |         68.3 |        38 |
|  39 | Salmon    |   423 |         68.2 |        70 |
|  40 | Bowron    |   245 |         74.8 |        43 |
|  41 | Nechako   |   208 |         95.8 |        63 |
|  42 | Mackenzie |   447 |         96.6 |        69 |
|  43 | Skeena    |   296 |         88.1 |        28 |
|  44 | Fraser    |   103 |         87.9 |        17 |
|  45 | Bulkley   |   325 |         80.4 |        24 |
|  46 | Stellako  |   454 |         60.1 |        63 |
|  47 | Endako    |   314 |         83.1 |        80 |
|  48 | Stuart    |   344 |         91.8 |        54 |
|  49 | Salmon    |   213 |         88.6 |        57 |
|  50 | Bowron    |   361 |         77.2 |        29 |

### Both directions

``` r
set.seed(42)
both_df <- data.frame(
  Row = 1:30,
  Site = rep(sites, 3),
  Plugs = sample(100:500, 30, replace = TRUE),
  Survival = round(runif(30, 60, 98), 1),
  Height_cm = round(runif(30, 15, 85), 0),
  BEC_Zone = rep(c("SBSdw3", "SBSmk1", "SBSdk", "SBSwk1", "SBSmc2",
                   "SBSdw1", "SBSwk3", "SBSdk", "SBSmw", "SBSdw2"), 3),
  Elevation = sample(400:900, 30, replace = TRUE),
  Lat = round(runif(30, 53, 56), 4),
  Lon = round(runif(30, -128, -122), 4),
  Source = rep(c("Local", "Transfer"), 15),
  Soil = rep(c("Silty clay", "Sandy loam", "Clay loam", "Silt loam", "Gravel"), 6),
  Moisture = rep(c("Subhygric", "Mesic", "Hygric", "Subxeric", "Mesic"), 6),
  Fish = rep(c("Yes", "Yes", "No", "Yes", "No"), 6),
  Permit = rep(c("Approved", "In review", "Not submitted", "Approved", "Pending"), 6)
)

cat(mc_scroll(knitr::kable(both_df, format = "html"), direction = "both"))
```

| Row | Site      | Plugs | Survival | Height_cm | BEC_Zone | Elevation |     Lat |       Lon | Source   | Soil       | Moisture  | Fish | Permit        |
|----:|:----------|------:|---------:|----------:|:---------|----------:|--------:|----------:|:---------|:-----------|:----------|:-----|:--------------|
|   1 | Nechako   |   148 |     60.3 |        34 | SBSdw3   |       724 | 55.7576 | -126.8728 | Local    | Silty clay | Subhygric | Yes  | Approved      |
|   2 | Mackenzie |   420 |     67.9 |        73 | SBSmk1   |       875 | 55.8877 | -127.8255 | Transfer | Sandy loam | Mesic     | Yes  | In review     |
|   3 | Skeena    |   252 |     94.5 |        64 | SBSdk    |       517 | 53.7006 | -127.1857 | Local    | Clay loam  | Hygric    | No   | Not submitted |
|   4 | Fraser    |   173 |     83.2 |        32 | SBSwk1   |       529 | 55.1735 | -123.9190 | Transfer | Silt loam  | Subxeric  | Yes  | Approved      |
|   5 | Bulkley   |   327 |     74.4 |        18 | SBSmc2   |       481 | 55.7109 | -122.3911 | Local    | Gravel     | Mesic     | No   | Pending       |
|   6 | Stellako  |   245 |     76.6 |        25 | SBSdw1   |       807 | 54.8104 | -124.6970 | Transfer | Silty clay | Subhygric | Yes  | Approved      |
|   7 | Endako    |   221 |     61.4 |        30 | SBSwk3   |       768 | 54.8945 | -124.3894 | Local    | Sandy loam | Mesic     | Yes  | In review     |
|   8 | Stuart    |   148 |     97.0 |        49 | SBSdk    |       801 | 55.8122 | -126.8180 | Transfer | Clay loam  | Hygric    | No   | Not submitted |
|   9 | Salmon    |   227 |     76.4 |        29 | SBSmw    |       724 | 55.5514 | -124.7886 | Local    | Silt loam  | Subxeric  | Yes  | Approved      |
|  10 | Bowron    |   402 |     96.4 |        65 | SBSdw2   |       509 | 54.7395 | -126.9227 | Transfer | Gravel     | Mesic     | No   | Pending       |
|  11 | Nechako   |   123 |     93.7 |        16 | SBSdw3   |       759 | 55.4642 | -125.2887 | Local    | Silty clay | Subhygric | Yes  | Approved      |
|  12 | Mackenzie |   426 |     84.3 |        41 | SBSmk1   |       838 | 53.3412 | -126.0977 | Transfer | Sandy loam | Mesic     | Yes  | In review     |
|  13 | Skeena    |   455 |     96.9 |        51 | SBSdk    |       695 | 55.2935 | -127.3030 | Local    | Clay loam  | Hygric    | No   | Not submitted |
|  14 | Fraser    |   188 |     83.5 |        15 | SBSwk1   |       548 | 54.8708 | -126.8834 | Transfer | Silt loam  | Subxeric  | Yes  | Approved      |
|  15 | Bulkley   |   264 |     72.7 |        56 | SBSmc2   |       883 | 53.4453 | -123.6216 | Local    | Gravel     | Mesic     | No   | Pending       |
|  16 | Stellako  |   209 |     73.2 |        26 | SBSdw1   |       456 | 53.2408 | -125.5288 | Transfer | Silty clay | Subhygric | Yes  | Approved      |
|  17 | Endako    |   119 |     75.1 |        40 | SBSwk3   |       499 | 54.3922 | -125.5157 | Local    | Sandy loam | Mesic     | Yes  | In review     |
|  18 | Stuart    |   469 |     89.8 |        60 | SBSdk    |       886 | 55.3381 | -125.1181 | Transfer | Clay loam  | Hygric    | No   | Not submitted |
|  19 | Salmon    |   466 |     61.5 |        69 | SBSmw    |       697 | 55.2006 | -125.4350 | Local    | Silt loam  | Subxeric  | Yes  | Approved      |
|  20 | Bowron    |   486 |     88.5 |        54 | SBSdw2   |       801 | 55.4517 | -127.1811 | Transfer | Gravel     | Mesic     | No   | Pending       |
|  21 | Nechako   |   396 |     85.7 |        31 | SBSdw3   |       490 | 53.5105 | -123.0519 | Local    | Silty clay | Subhygric | Yes  | Approved      |
|  22 | Mackenzie |   188 |     66.5 |        21 | SBSmk1   |       668 | 55.8342 | -124.4462 | Transfer | Sandy loam | Mesic     | Yes  | In review     |
|  23 | Skeena    |   382 |     69.9 |        21 | SBSdk    |       580 | 53.8809 | -123.2336 | Local    | Clay loam  | Hygric    | No   | Not submitted |
|  24 | Fraser    |   208 |     79.5 |        36 | SBSwk1   |       453 | 53.4472 | -123.3858 | Transfer | Silt loam  | Subxeric  | Yes  | Approved      |
|  25 | Bulkley   |   104 |     85.7 |        62 | SBSmc2   |       738 | 55.1581 | -122.4917 | Local    | Gravel     | Mesic     | No   | Pending       |
|  26 | Stellako  |   311 |     97.3 |        15 | SBSdw1   |       687 | 53.9723 | -122.8242 | Transfer | Silty clay | Subhygric | Yes  | Approved      |
|  27 | Endako    |   447 |     88.9 |        30 | SBSwk3   |       607 | 55.3364 | -126.0981 | Local    | Sandy loam | Mesic     | Yes  | In review     |
|  28 | Stuart    |   459 |     81.5 |        80 | SBSdk    |       645 | 54.1833 | -126.4444 | Transfer | Clay loam  | Hygric    | No   | Not submitted |
|  29 | Salmon    |   358 |     92.3 |        80 | SBSmw    |       459 | 55.0358 | -123.5464 | Local    | Silt loam  | Subxeric  | Yes  | Approved      |
|  30 | Bowron    |   413 |     67.2 |        66 | SBSdw2   |       684 | 55.3275 | -123.5158 | Transfer | Gravel     | Mesic     | No   | Pending       |

The default `max_height` for vertical scrolling is `"400px"`. Adjust
with `mc_scroll(..., max_height = "600px")`.

## Full workflow

``` r
library(mc)

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

mc_send(html = body,
        to = "brandon@example.com",
        subject = "2026 planting plan — cottonwood plugs")
```

## Scheduled send

Use `send_at` to send an email later. This works with
[`mc_compose()`](https://newgraphenvironment.github.io/mc/reference/mc_compose.md)
and
[`mc_scroll()`](https://newgraphenvironment.github.io/mc/reference/mc_scroll.md)
— build the body now, send it when you want.

``` r
library(mc)

sites <- data.frame(
  Site = c("Nechako", "Mackenzie", "Skeena"),
  Plugs = c(4000, 3000, 3000),
  Season = c("Fall 2026", "Fall 2026", "Fall 2026")
)

body <- mc_compose(
  "<p>Hi Brandon,</p>
   <p>Here's the planting plan with a scrollable table:</p>",
  mc_scroll(
    kableExtra::kbl(sites, format = "html") |>
      kableExtra::kable_styling(full_width = FALSE) |>
      kableExtra::row_spec(0, bold = TRUE, background = "#f5f5f5"),
    direction = "both"
  ),
  "<p>Let me know if the numbers look right.</p>"
)

# Send in 30 minutes
proc <- mc_send(html = body,
                to = "brandon@example.com",
                subject = "2026 planting plan",
                send_at = 30)

# Or at a specific time
mc_send(html = body,
        to = "brandon@example.com",
        subject = "2026 planting plan",
        send_at = as.POSIXct("2026-02-24 09:00:00"))

# Check or cancel
proc$is_alive()
proc$kill()
```

On macOS, `caffeinate` prevents the machine from sleeping until the
email sends. The laptop lid can be closed as long as power is connected.
If the machine does sleep through the send window, a 5-minute grace
period applies — past that the send is skipped to prevent stale emails
firing.
