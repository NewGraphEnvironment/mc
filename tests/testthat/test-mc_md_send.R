write_draft <- function(lines) {
  p <- tempfile(fileext = ".md")
  writeLines(lines, p)
  p
}

test_that("mc_md_send rejects bad input", {
  expect_error(mc_md_send(123))
  expect_error(mc_md_send("x", draft = "yes"))
  expect_error(mc_md_send("x", override = "bad"))
})

test_that("mc_md_send errors when required fields missing", {
  p <- write_draft(c("---", "cc: b@x.com", "---", "body"))
  expect_error(mc_md_send(p), "to, subject")
})

test_that("mc_md_send dispatches frontmatter fields to mc_send", {
  captured <- NULL
  fake_send <- function(...) {
    captured <<- list(...)
    invisible(NULL)
  }
  mockery::stub(mc_md_send, "mc_send", fake_send)
  p <- write_draft(c(
    "---",
    "to: a@x.com",
    "subject: Hello",
    "cc: [b@x.com]",
    "thread_id: tid1",
    "attachments: [/tmp/x.pdf]",
    "labels: [project-x, urgent]",
    "---",
    "body"
  ))
  mc_md_send(p)
  expect_equal(captured$to, "a@x.com")
  expect_equal(captured$subject, "Hello")
  expect_equal(captured$cc, "b@x.com")
  expect_equal(captured$thread_id, "tid1")
  expect_equal(captured$attachments, "/tmp/x.pdf")
  expect_equal(captured$labels, c("project-x", "urgent"))
  expect_true(captured$draft)
  expect_false(captured$test)
  expect_equal(captured$path, p)
})

test_that("mc_md_send passes NULL labels when frontmatter omits them", {
  captured <- NULL
  mockery::stub(mc_md_send, "mc_send", function(...) {
    captured <<- list(...); invisible(NULL)
  })
  p <- write_draft(c("---", "to: a@x.com", "subject: Hi", "---", "body"))
  mc_md_send(p)
  expect_null(captured$labels)
})

test_that("mc_md_send coerces empty labels list to NULL", {
  captured <- NULL
  mockery::stub(mc_md_send, "mc_send", function(...) {
    captured <<- list(...); invisible(NULL)
  })
  # `labels: []` parses to list() — should pass through as NULL
  p_empty <- write_draft(c(
    "---", "to: a@x.com", "subject: Hi", "labels: []", "---", "body"
  ))
  mc_md_send(p_empty)
  expect_null(captured$labels)

  # `labels: ~` (explicit yaml null) — same outcome
  captured <- NULL
  p_null <- write_draft(c(
    "---", "to: a@x.com", "subject: Hi", "labels: ~", "---", "body"
  ))
  mc_md_send(p_null)
  expect_null(captured$labels)
})

test_that("mc_md_send rejects path in override", {
  p <- write_draft(c("---", "to: a@x.com", "subject: hi", "---", "body"))
  expect_error(
    mc_md_send(p, override = list(path = "/other.md")),
    "cannot change"
  )
})

test_that("mc_md_send override wins over frontmatter", {
  captured <- NULL
  fake_send <- function(...) {
    captured <<- list(...)
    invisible(NULL)
  }
  mockery::stub(mc_md_send, "mc_send", fake_send)
  p <- write_draft(c(
    "---", "to: a@x.com", "subject: Hi", "---", "body"
  ))
  mc_md_send(p, override = list(draft = FALSE, subject = "Overridden"))
  expect_false(captured$draft)
  expect_equal(captured$subject, "Overridden")
})

test_that("mc_md_send passes draft/test flags through", {
  captured <- NULL
  mockery::stub(mc_md_send, "mc_send", function(...) {
    captured <<- list(...); invisible(NULL)
  })
  p <- write_draft(c("---", "to: a@x.com", "subject: Hi", "---", "body"))
  mc_md_send(p, draft = FALSE, test = TRUE)
  expect_false(captured$draft)
  expect_true(captured$test)
})
