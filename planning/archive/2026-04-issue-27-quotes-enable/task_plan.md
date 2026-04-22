# Task Plan: Enable Startup Quotes in mc

Applies the `/quotes-enable` soul skill + drift's data-raw scaffold pattern to mc. `library(mc)` will print a random fact-checked quote on attach (italic quote, grey author, blue clickable source).

## Phase 1: Inputs
- [x] 25-person list: MLK, JFK, Bob Marley, Chris Cornell, Kurt Cobain, Ice-T, Ice Cube, Eminem, Mike Tyson, Vince Staples, Jim Carrey, John Candy, Ronnie Chieng, Jon Stewart, DJ Premier, Logic, RZA, ODB, Method Man, Stephen King, Quentin Tarantino, Paul Thomas Anderson, 2Pac, Robert Plant, James Hetfield
- [x] Themes: art, love, life, meaning, success, pain

## Phase 2: Research (parallel)
- [x] 6 research agents clustered by domain; 112 candidates returned

## Phase 3: Fact-check (parallel)
- [x] Tier-2 agent on chain-source/book-source; 11 PRIMARY_VERIFIED, 9 CHAIN_ONLY (kept for canonical published books)
- [x] Spot-check agent on direct-primary URLs; 1 drop (2Pac composite)

## Phase 4: Calibration filter + user review
- [x] User reviewed shipped CSV directly; removed 13 for personal curation → 99 final

## Phase 5: Infrastructure
- [x] `R/zzz.R` (cli::style_italic, col_grey, col_blue, style_hyperlink)
- [x] `inst/extdata/quotes.csv` (99 rows)
- [x] `data-raw/quotes_build.R` (tibble = source of truth)
- [x] `data-raw/quotes_audit.csv` (generated, matches shipped)
- [x] `data-raw/README.md`
- [x] `cli` added to Imports in DESCRIPTION
- [x] `data-raw` already in `.Rbuildignore`

## Phase 6: Verify + ship
- [x] `devtools::load_all()` — quote prints (italic + grey + blue source)
- [x] `R CMD check` — no new errors/warnings (1 pre-existing test failure + warning unrelated)
- [x] DESCRIPTION Version 0.2.6
- [x] NEWS entry
- [ ] Commit, push, PR
- [ ] Archive planning after merge
