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
               paste0("---\ndraft_id: \"r-123\"\nto: a@x.com\nsubject: Hi\n---\n", body))
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
               "---\r\ndraft_id: \"r-1\"\r\nto: a@x.com\r\nsubject: Hi\r\n---\r\nbody\r\n")
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
  expect_equal(read_bytes(p), "---\ndraft_id: \"r-5\"\nto: a@x.com\n---\ndraft_id: in the body\n")
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

test_that("frontmatter_set leaves a file alone when the line would not read back", {
  # Flow style: a line appended after {...} is a YAML parse error
  txt <- "---\n{to: a@x.com, subject: Hi}\n---\nbody\n"
  d <- tempfile()
  dir.create(d)
  p <- file.path(d, "draft.md")
  writeBin(charToRaw(txt), p)
  expect_error(frontmatter_set(p, "draft_id", "r-1"), "read back")
  expect_equal(read_bytes(p), txt)
  expect_equal(list.files(d), "draft.md")
})

test_that("to_self neither replaces nor records the file's draft", {
  txt <- "---\nto: a@x.com\nsubject: Hi\ndraft_id: \"r-real\"\n---\nbody\n"
  p <- write_bytes(txt)
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(list(draft_id = "r-test", thread_id = "t", message_id = "m"))
  })
  mc_md_draft(p, to_self = TRUE)
  expect_null(captured$draft_id)
  expect_equal(read_bytes(p), txt)
})

test_that("an empty draft_id in the frontmatter counts as none", {
  p <- write_bytes("---\nto: a@x.com\nsubject: Hi\ndraft_id: \"\"\n---\nbody\n")
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(list(draft_id = "r-1", thread_id = "t", message_id = "m"))
  })
  suppressMessages(mc_md_draft(p))
  expect_null(captured$draft_id)
  expect_equal(mc_md_meta(p)$draft_id, "r-1")
})

test_that("mc_md_send refuses override draft_id against the real mc_send signature", {
  p <- write_bytes("---\nto: a@x.com\nsubject: Hi\n---\nbody\n")
  local_mocked_bindings(
    gm_send_message = function(...) stop("must not send"),
    .package = "gmailr"
  )
  expect_error(mc_md_send(p, override = list(draft_id = "r1")), "mc_md_draft")
})

test_that("mc_md_send with draft_id in the frontmatter reaches the real mc_send and says the draft remains", {
  p <- write_bytes("---\nto: a@x.com\nsubject: Hi\ndraft_id: \"r-1\"\nfrom: me@x.com\nsig: false\n---\nbody\n")
  env <- new.env()
  local_mocked_bindings(
    gm_send_message = function(msg, ...) {
      env$sent <- TRUE
      list(threadId = "t")
    },
    .package = "gmailr"
  )
  expect_message(mc_md_send(p), "Draft r-1 from this file is still in Gmail")
  expect_true(env$sent)
})

test_that("override = list(to_self = TRUE) is a test copy too", {
  txt <- "---\nto: a@x.com\nsubject: Hi\ndraft_id: \"r-real\"\n---\nbody\n"
  p <- write_bytes(txt)
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(list(draft_id = "r-test", thread_id = "t", message_id = "m"))
  })
  mc_md_draft(p, override = list(to_self = TRUE))
  expect_null(captured$draft_id)
  expect_equal(read_bytes(p), txt)
})

test_that("a block scalar ending the frontmatter does not stop the id being recorded", {
  txt <- "---\nto: a@x.com\nsubject: Hi\nnotes: |\n  line one\n---\nbody\n"
  p <- write_bytes(txt)
  mockery::stub(mc_md_draft, "mc_draft", fake_draft("r-7"))
  expect_no_warning(suppressMessages(mc_md_draft(p)))
  expect_equal(mc_md_meta(p)$draft_id, "r-7")
  expect_equal(mc_md_meta(p)$notes, "line one")
})

test_that("frontmatter keys are read exactly, never by prefix", {
  # A sibling key that starts with a field's name must not stand in for it
  p <- write_bytes(paste0(
    "---\nto: a@x.com\nsubject: Hi\ndraft_id_old: \"r-OTHER\"\n",
    "cc_old: old@x.com\nthread_id_was: t-OLD\n---\nbody\n"
  ))
  captured <- NULL
  mockery::stub(mc_md_draft, "mc_draft", function(...) {
    captured <<- list(...)
    invisible(list(draft_id = "r-new", thread_id = "t", message_id = "m"))
  })
  suppressMessages(mc_md_draft(p))
  expect_null(captured$draft_id)
  expect_null(captured$cc)
  expect_null(captured$thread_id)
  expect_equal(mc_md_meta(p)[["draft_id"]], "r-new")

  sent <- NULL
  mockery::stub(mc_md_send, "mc_send", function(...) {
    sent <<- list(...)
    invisible("t")
  })
  mc_md_send(p)
  expect_null(sent$cc)
  expect_null(sent$thread_id)
})

test_that("frontmatter_set through a symlink writes the target and keeps the link", {
  skip_on_os("windows")
  d <- tempfile()
  dir.create(d)
  real <- file.path(d, "real.md")
  link <- file.path(d, "link.md")
  writeBin(charToRaw("---\nto: a@x.com\n---\nbody\n"), real)
  file.symlink(real, link)
  frontmatter_set(link, "draft_id", "r-1")
  expect_true(nzchar(Sys.readlink(link)))
  expect_equal(parse_frontmatter(real)$meta[["draft_id"]], "r-1")
})
