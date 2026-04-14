test_that("mc_md_meta rejects bad input", {
  expect_error(mc_md_meta(123))
})

test_that("mc_md_meta returns parsed frontmatter", {
  p <- tempfile(fileext = ".md")
  writeLines(c("---", "to: a@x.com", "subject: hi", "---", "body"), p)
  m <- mc_md_meta(p)
  expect_equal(m$to, "a@x.com")
  expect_equal(m$subject, "hi")
})

test_that("mc_md_meta returns empty list when no frontmatter", {
  p <- tempfile(fileext = ".md")
  writeLines(c("body only"), p)
  expect_equal(mc_md_meta(p), list())
})
