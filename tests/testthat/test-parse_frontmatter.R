test_that("strip_md_header strips YAML frontmatter block", {
  md <- "---\nto: a@x.com\nsubject: hi\n---\nBody here\n"
  out <- mc:::strip_md_header(md)
  expect_equal(out, "Body here\n")
})

test_that("strip_md_header still strips legacy compost header", {
  md <- "# Email to X\n**Subject:** Foo\n\n---\n\nBody here\n"
  out <- mc:::strip_md_header(md)
  expect_equal(out, "Body here\n")
})

test_that("strip_md_header passes through when no separator", {
  md <- "Just a body\nwith no separator\n"
  expect_equal(mc:::strip_md_header(md), md)
})

test_that("parse_frontmatter returns meta and body when YAML present", {
  p <- tempfile(fileext = ".md")
  writeLines(c("---", "to: a@x.com", "subject: Hi there",
               "cc: [b@x.com, c@x.com]", "---", "Body line one", "Body line two"),
             p)
  r <- mc:::parse_frontmatter(p)
  expect_equal(r$meta$to, "a@x.com")
  expect_equal(r$meta$subject, "Hi there")
  expect_equal(r$meta$cc, c("b@x.com", "c@x.com"))
  expect_true(grepl("Body line one", r$body))
})

test_that("parse_frontmatter returns empty meta when no frontmatter", {
  p <- tempfile(fileext = ".md")
  writeLines(c("# Email to X", "---", "Body"), p)
  r <- mc:::parse_frontmatter(p)
  expect_equal(r$meta, list())
  expect_true(grepl("Body", r$body))
})

test_that("parse_frontmatter errors on missing file", {
  expect_error(mc:::parse_frontmatter("/nonexistent/path.md"))
})
