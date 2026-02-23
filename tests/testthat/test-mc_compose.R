test_that("mc_compose combines HTML strings", {
  body <- mc_compose("<p>Hello</p>", "<p>World</p>", sig = FALSE)
  expect_match(body, "Hello")
  expect_match(body, "World")
})

test_that("mc_compose renders markdown files", {
  tmp <- tempfile(fileext = ".md")
  writeLines(c("# Header", "", "---", "", "Body **text**."), tmp)

  body <- mc_compose(tmp, sig = FALSE)
  expect_match(body, "<strong>text</strong>")
  expect_false(grepl("Header", body))

  unlink(tmp)
})

test_that("mc_compose handles knitr::kable objects", {
  df <- data.frame(Site = c("A", "B"), N = c(1, 2))
  tbl <- knitr::kable(df, format = "html")

  body <- mc_compose("<p>Intro</p>", tbl, "<p>Outro</p>", sig = FALSE)
  expect_match(body, "Intro")
  expect_match(body, "Outro")
  expect_match(body, "<table")
  expect_match(body, "border: 1px solid #ddd")
})

test_that("mc_compose inlines styles on kable tables", {
  df <- data.frame(X = 1:2)
  tbl <- knitr::kable(df, format = "html")

  body <- mc_compose(tbl, sig = FALSE)
  # th and td should have border/padding
  expect_match(body, '<th[^>]*border: 1px solid #ddd')
  expect_match(body, '<td[^>]*border: 1px solid #ddd')
  expect_match(body, '<td[^>]*padding: 8px')
})

test_that("mc_compose appends signature by default", {
  body <- mc_compose("<p>Hi</p>")
  expect_match(body, "Al Irvine")
})

test_that("mc_compose uses custom sig_path", {
  sig_tmp <- tempfile(fileext = ".html")
  writeLines("<br>Custom Sig", sig_tmp)

  body <- mc_compose("<p>Hi</p>", sig_path = sig_tmp)
  expect_match(body, "Custom Sig")
  expect_false(grepl("Al Irvine", body))

  unlink(sig_tmp)
})

test_that("mc_compose errors on empty input", {
  expect_error(mc_compose(sig = FALSE), "at least one")
})

test_that("mc_compose errors on bad types", {
  expect_error(mc_compose(123, sig = FALSE))
  expect_error(mc_compose(sig = "yes"))
})

test_that("mc_compose mixes md file, kable, and HTML", {
  md_tmp <- tempfile(fileext = ".md")
  writeLines(c("---", "", "Opening paragraph."), md_tmp)

  df <- data.frame(Site = "Nechako", Plugs = 4000)
  tbl <- knitr::kable(df, format = "html")

  body <- mc_compose(md_tmp, tbl, "<p>Closing.</p>", sig = FALSE)
  expect_match(body, "Opening paragraph")
  expect_match(body, "Nechako")
  expect_match(body, "Closing")

  unlink(md_tmp)
})

test_that("inline_table_styles merges with existing kable styles", {
  # kable output has style="text-align:left;" on th/td
  html <- '<th style="text-align:left;"> Site </th>'
  styled <- mc:::inline_table_styles(html)
  # Should have both border and original alignment
  expect_match(styled, "border: 1px solid #ddd")
  expect_match(styled, "text-align:left")
})

test_that("inline_table_styles handles kableExtra class tables", {
  html <- '<table class="table" style="width: auto;">'
  styled <- mc:::inline_table_styles(html)
  expect_match(styled, "border-collapse")
  expect_match(styled, "width: auto")
})
