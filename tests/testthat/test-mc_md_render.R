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

test_that("markdown links of every kind open in a new tab", {
  md <- tempfile(fileext = ".md")
  writeLines(c(
    "[plain](https://a.com) [titled](https://b.com \"T\")",
    "<https://c.com> www.d.com [mail](mailto:x@y.com)"
  ), md)
  html <- mc_md_render(md, sig = FALSE)
  anchors <- regmatches(html, gregexpr("<a\\s[^>]*>", html, perl = TRUE))[[1]]
  expect_length(anchors, 5)
  for (a in anchors) {
    expect_equal(count_fixed(a, 'target="_blank"'), 1, info = a)
    expect_equal(count_fixed(a, 'rel="noopener noreferrer"'), 1, info = a)
  }
  expect_match(html, '<a href="https://b.com" title="T" target="_blank" rel="noopener noreferrer">', fixed = TRUE)
})

test_that("a link that already sets target or rel is not given a second one", {
  html <- mc:::inject_link_target(paste0(
    '<a href="https://a.com" target="_self">a</a>',
    "<a href='https://b.com' rel='nofollow'>b</a>",
    '<a name="top">c</a>'
  ))
  expect_match(html, '<a href="https://a.com" target="_self" rel="noopener noreferrer">', fixed = TRUE)
  expect_match(html, "<a href='https://b.com' rel='nofollow' target=\"_blank\">", fixed = TRUE)
  # An anchor with no href is not a link
  expect_match(html, '<a name="top">', fixed = TRUE)
  expect_identical(mc:::inject_link_target(html), html)
})

test_that("HTML without links is unchanged", {
  x <- "<p>no links, <abbr>abbr</abbr> and <address>here</address></p>"
  expect_identical(mc:::inject_link_target(x), x)
})

test_that("a link within the message stays in the message", {
  x <- '<a href="#notes">see notes</a>'
  expect_identical(mc:::inject_link_target(x), x)
})

test_that("attribute names are read outside quoted values", {
  html <- mc:::inject_link_target('<a href="https://a.com" title="no target=here, rel=none">a</a>')
  expect_match(html, 'target="_blank" rel="noopener noreferrer">a</a>', fixed = TRUE)
})

test_that("an unquoted style attribute is merged, not duplicated", {
  html <- mc:::inline_table_styles("<td style=color:red>1</td>")
  expect_identical(html, '<td style="border: 1px solid #ddd; padding: 8px; color:red">1</td>')
})
