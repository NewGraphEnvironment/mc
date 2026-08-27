write_md <- function(lines) {
  p <- tempfile(fileext = ".md")
  writeLines(lines, p)
  p
}

test_that("mc_md_draft rejects bad input", {
  expect_error(mc_md_draft(123))
  expect_error(mc_md_draft("x", to_self = "yes"))
  expect_error(mc_md_draft("x", override = "bad"))
})

test_that("mc_md_draft errors when required fields missing", {
  p <- write_md(c("---", "cc: b@x.com", "---", "body"))
  expect_error(mc_md_draft(p), "to, subject")
})

test_that("mc_md_draft dispatches frontmatter fields to mc_draft", {
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...); invisible(NULL)
  })
  p <- write_md(c(
    "---",
    "to: a@x.com",
    "subject: Hello",
    "cc: [b@x.com]",
    "attachments: [/tmp/x.pdf]",
    "labels: [project-x, urgent]",
    "---",
    "body"
  ))
  mc_md_draft(p)
  expect_equal(captured$to, "a@x.com")
  expect_equal(captured$subject, "Hello")
  expect_equal(captured$cc, "b@x.com")
  expect_equal(captured$attachments, "/tmp/x.pdf")
  expect_equal(captured$labels, c("project-x", "urgent"))
  expect_false(captured$to_self)
  expect_equal(captured$path, p)
})

test_that("mc_md_draft passes to_self through", {
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...); invisible(NULL)
  })
  p <- write_md(c("---", "to: a@x.com", "subject: Hi", "---", "body"))
  mc_md_draft(p, to_self = TRUE)
  expect_true(captured$to_self)
})

test_that("mc_md_draft coerces empty labels list to NULL", {
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...); invisible(NULL)
  })
  p <- write_md(c("---", "to: a@x.com", "subject: Hi", "labels: []",
                  "---", "body"))
  mc_md_draft(p)
  expect_null(captured$labels)
})

test_that("mc_md_draft override rejects the removed draft and test keys", {
  p <- write_md(c("---", "to: a@x.com", "subject: Hi", "---", "body"))
  expect_error(mc_md_draft(p, override = list(draft = TRUE)), "mc_md_draft")
  expect_error(mc_md_draft(p, override = list(test = TRUE)), "to_self")
})

test_that("mc_md_draft override cannot change path", {
  p <- write_md(c("---", "to: a@x.com", "subject: Hi", "---", "body"))
  expect_error(mc_md_draft(p, override = list(path = "other.md")), "cannot change")
})
