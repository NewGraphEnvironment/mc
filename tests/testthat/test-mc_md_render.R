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
