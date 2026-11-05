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
    captured <<- list(...)
    invisible(NULL)
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
    captured <<- list(...)
    invisible(NULL)
  })
  p <- write_md(c("---", "to: a@x.com", "subject: Hi", "---", "body"))
  mc_md_draft(p, to_self = TRUE)
  expect_true(captured$to_self)
})

test_that("mc_md_draft coerces empty labels list to NULL", {
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(NULL)
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

# --- draft_id in the frontmatter (#51) ---------------------------------------

write_bytes <- function(txt) {
  p <- tempfile(fileext = ".md")
  writeBin(charToRaw(txt), p)
  p
}
read_bytes <- function(p) rawToChar(readBin(p, "raw", file.size(p)))
fake_draft <- function(id) {
  function(...) invisible(list(draft_id = id, thread_id = "t", message_id = "m"))
}

test_that("mc_md_draft records a new draft's id in the frontmatter, body untouched", {
  body <- "Hello,\n\nA body with --- in it.\n\n---\n\nAnd a rule.\n"
  p <- write_bytes(paste0("---\nto: a@x.com\nsubject: Hi\n---\n", body))
  mockery::stub(mc_md_draft, "mc_draft", fake_draft("r-123"))
  expect_message(res <- mc_md_draft(p), "Recorded draft_id r-123")
  expect_equal(res$draft_id, "r-123")
  expect_equal(mc_md_meta(p)$draft_id, "r-123")
  expect_equal(read_bytes(p),
               paste0("---\nto: a@x.com\nsubject: Hi\ndraft_id: \"r-123\"\n---\n", body))
})

test_that("running the file again replaces its own draft and leaves the file alone", {
  p <- write_bytes("---\nto: a@x.com\ndraft_id: \"r-123\"\nsubject: Hi\n---\nbody\n")
  before <- tools::md5sum(p)
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(list(draft_id = "r-123", thread_id = "t", message_id = "m"))
  })
  mc_md_draft(p)
  expect_equal(captured$draft_id, "r-123")
  expect_equal(unname(tools::md5sum(p)), unname(before))
})

test_that("a replacement draft's new id overwrites the stale line, not a second one", {
  p <- write_bytes("---\nto: a@x.com\ndraft_id: \"r-old\"\nsubject: Hi\n---\nbody")
  mockery::stub(mc_md_draft, "mc_draft", fake_draft("r-new"))
  suppressMessages(mc_md_draft(p))
  expect_equal(read_bytes(p),
               "---\nto: a@x.com\ndraft_id: \"r-new\"\nsubject: Hi\n---\nbody")
})

test_that("the write keeps CRLF line endings", {
  p <- write_bytes("---\r\nto: a@x.com\r\nsubject: Hi\r\n---\r\nbody\r\n")
  mockery::stub(mc_md_draft, "mc_draft", fake_draft("r-1"))
  suppressMessages(mc_md_draft(p))
  expect_equal(read_bytes(p),
               "---\r\nto: a@x.com\r\nsubject: Hi\r\ndraft_id: \"r-1\"\r\n---\r\nbody\r\n")
})

test_that("override = list(draft_id = ) wins over the frontmatter", {
  p <- write_bytes("---\nto: a@x.com\nsubject: Hi\ndraft_id: \"r-file\"\n---\nbody\n")
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(list(draft_id = "r-arg", thread_id = "t", message_id = "m"))
  })
  suppressMessages(mc_md_draft(p, override = list(draft_id = "r-arg")))
  expect_equal(captured$draft_id, "r-arg")
  expect_equal(mc_md_meta(p)$draft_id, "r-arg")
})

test_that("a failed write warns with the id and still returns the result", {
  p <- write_bytes("---\nto: a@x.com\nsubject: Hi\n---\nbody\n")
  mockery::stub(mc_md_draft, "mc_draft", fake_draft("r-9"))
  mockery::stub(mc_md_draft, "frontmatter_set", function(...) stop("disk full"))
  expect_warning(res <- mc_md_draft(p), "r-9 created.*disk full")
  expect_equal(res$draft_id, "r-9")
})

test_that("frontmatter_set refuses a value that is not a plain id", {
  p <- write_bytes("---\nto: a@x.com\n---\nbody\n")
  expect_error(frontmatter_set(p, "draft_id", "x\ny: 1"), "Refusing")
  expect_equal(read_bytes(p), "---\nto: a@x.com\n---\nbody\n")
})

test_that("frontmatter_set refuses a file with two lines for the key", {
  p <- write_bytes("---\ndraft_id: a\ndraft_id: b\n---\nbody\n")
  expect_error(frontmatter_set(p, "draft_id", "c"), "More than one")
})

test_that("frontmatter_set reads the block parse_frontmatter reads", {
  # A key-like line in the body after the block must not be touched
  p <- write_bytes("---\nto: a@x.com\n---\ndraft_id: in the body\n")
  frontmatter_set(p, "draft_id", "r-5")
  expect_equal(read_bytes(p), "---\nto: a@x.com\ndraft_id: \"r-5\"\n---\ndraft_id: in the body\n")
  expect_equal(parse_frontmatter(p)$meta$draft_id, "r-5")
})

test_that("mc_md_send ignores draft_id in the frontmatter", {
  p <- write_bytes("---\nto: a@x.com\nsubject: Hi\ndraft_id: \"r-1\"\n---\nbody\n")
  captured <- NULL
  mockery::stub(mc_md_send, "mc_send", function(...) {
    captured <<- list(...)
    invisible("t")
  })
  mc_md_send(p)
  expect_false("draft_id" %in% names(captured))
})
