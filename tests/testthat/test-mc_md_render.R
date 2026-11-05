test_that("mc_md_render strips header and converts to HTML", {
  # Create a temp markdown file with header
  tmp <- tempfile(fileext = ".md")
  writeLines(c(
    "# Email to Test",
    "",
    "**Subject:** Test",
    "",
    "---",
    "",
    "Hi there,",
    "",
    "This is a **test**.",
    "",
    "| Col A | Col B |",
    "|-------|-------|",
    "| 1     | 2     |"
  ), tmp)

  html <- mc_md_render(tmp, sig = FALSE)

  # Header should be stripped
  expect_false(grepl("Email to Test", html))

  # Body should be HTML

  expect_match(html, "<strong>test</strong>")
  expect_match(html, "Hi there")

  # Table should have inline styles
  expect_match(html, "border-collapse")
  expect_match(html, "padding: 8px")

  unlink(tmp)
})

test_that("mc_md_render appends signature by default", {
  tmp <- tempfile(fileext = ".md")
  writeLines(c("---", "", "Hello."), tmp)

  html <- mc_md_render(tmp, sig = TRUE)
  expect_match(html, "Al Irvine")
  expect_match(html, "250-777-1518")

  unlink(tmp)
})

test_that("mc_md_render uses custom signature when sig_path is set", {
  sig_tmp <- tempfile(fileext = ".html")
  writeLines("<br>Jane Doe<br>Acme Corp", sig_tmp)

  md_tmp <- tempfile(fileext = ".md")
  writeLines(c("---", "", "Hello."), md_tmp)

  html <- mc_md_render(md_tmp, sig = TRUE, sig_path = sig_tmp)
  expect_match(html, "Jane Doe")
  expect_false(grepl("Al Irvine", html))

  unlink(c(sig_tmp, md_tmp))
})

test_that("mc_md_render errors on missing file", {
  expect_error(mc_md_render("/nonexistent/file.md"), "File not found")
})

count_fixed <- function(x, pattern) lengths(regmatches(x, gregexpr(pattern, x, fixed = TRUE)))

test_that("each table style declaration is written once per element", {
  md <- tempfile(fileext = ".md")
  writeLines(c("| a | b | c |", "|---|:--|--:|", "| 1 | 2 | 3 |"), md)
  html <- mc_md_render(md, sig = FALSE)
  tags <- regmatches(html, gregexpr("<(table|th|td)(\\s[^>]*)?>", html, perl = TRUE))[[1]]
  expect_length(tags, 7)
  for (t in tags) {
    expect_equal(count_fixed(t, "style="), 1, info = t)
    decl <- if (startsWith(t, "<table")) "border-collapse: collapse;" else "border: 1px solid #ddd;"
    expect_equal(count_fixed(t, decl), 1, info = t)
  }
})

test_that("aligned cells keep their alignment and gain the cell style", {
  html <- mc:::inline_table_styles('<th align="left">a</th><td align="right">1</td>')
  expect_match(html, '<th align="left" style="border: 1px solid #ddd; padding: 8px;">', fixed = TRUE)
  expect_match(html, '<td align="right" style="border: 1px solid #ddd; padding: 8px;">', fixed = TRUE)
})

test_that("existing inline styles are merged, in either quote style", {
  html <- mc:::inline_table_styles(paste0(
    '<table class="t" style="margin-left: auto;"><thead><tr>',
    "<th style='font-weight: bold;'>a</th></tr></thead></table>"
  ))
  expect_match(html, '<table class="t" style="border-collapse: collapse; margin: 12px 0; margin-left: auto;">',
               fixed = TRUE)
  expect_match(html, "<th style='border: 1px solid #ddd; padding: 8px; font-weight: bold;'>", fixed = TRUE)
  # <thead> and <tbody> are not cells
  expect_match(html, "<thead>", fixed = TRUE)
})

test_that("styling is idempotent, so a styled body passed through mc_compose is not styled twice", {
  once <- mc:::inline_table_styles('<table><tr><th>a</th><td align="left">1</td></tr></table>')
  expect_identical(mc:::inline_table_styles(once), once)
})
