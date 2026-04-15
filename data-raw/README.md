# data-raw/quotes

Source and provenance for the startup quotes shown on `library(mc)`.

## Files

- `quotes_build.R` — **source of truth**. R tibble with full provenance columns. Run to regenerate outputs.
- `quotes_audit.csv` — generated, full audit trail (source_type, source_outlet, verification_date). In the repo, excluded from the built package via `.Rbuildignore`.
- `../inst/extdata/quotes.csv` — generated, slim shipped CSV (quote, author, source). Read by `R/zzz.R` on attach.

## To add / edit / remove a quote

1. Edit the `quotes` tibble in `quotes_build.R`
2. Every row must have a primary-source URL where the exact text was confirmed via a direct fetch on the recorded `verification_date`
3. Run `Rscript data-raw/quotes_build.R` from the repo root
4. Both output CSVs regenerate; commit all three files together

## Runtime toggle: show source URL on attach

`R/zzz.R` prints a clickable `source` hyperlink (OSC 8) alongside the quote by default. Works in RStudio (2022.12+) and modern terminals. In environments without OSC 8 support, the word `source` renders as plain text. Suppress entirely:

```r
options(mc.quote_show_source = FALSE)
library(mc)
```

Set the option in `~/.Rprofile` for a persistent suppression. Default is `TRUE`.

## Standards

- **Primary source required** — published-outlet interviews, speeches, documentary transcripts. Book quotes accepted when the book is canonical and cross-circulated widely.
- **No padding** — drop a candidate rather than pad to a count.
- **UTF-8 throughout** — `.onAttach` reads with `encoding = "UTF-8"`.

## History

See `planning/archive/` for research logs, fact-check agent transcripts, and drop decisions.
