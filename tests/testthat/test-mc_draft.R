# mc_draft() can only draft. The whole point of the split (#39) is that no
# argument reaches gm_send_message() from here, so several of these tests mock
# gm_send_message() to stop() and assert the call still succeeds.

test_that("mc_draft errors without path or html", {
  expect_error(
    mc_draft(to = "test@test.com", subject = "test"),
    "Provide either"
  )
})

test_that("mc_draft builds MIME message and returns the draft thread id", {
  captured_msg <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured_msg <<- msg
      list(message = list(threadId = "draft_thread_001"))
    },
    .package = "gmailr"
  )
  res <- mc_draft(
    html = "<p>hello</p>", to = "bob@example.com",
    subject = "Test subject", from = "alice@example.com"
  )
  expect_false(is.null(captured_msg))
  expect_equal(res, "draft_thread_001")
})

test_that("mc_draft never calls gm_send_message", {
  local_mocked_bindings(
    gm_create_draft = function(msg) list(message = list(threadId = "t1")),
    gm_send_message = function(msg, ...) stop("mc_draft must never send"),
    .package = "gmailr"
  )
  expect_no_error(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "no send", from = "alice@example.com"
    )
  )
})

test_that("mc_draft to_self overrides to/cc/bcc/thread_id", {
  captured <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured <<- msg
      list(message = list(threadId = "t2"))
    },
    .package = "gmailr"
  )
  expect_no_warning(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "self", from = "alice@example.com",
      cc = "carol@example.com", bcc = "dave@example.com",
      thread_id = "abc123", to_self = TRUE
    )
  )
  hdrs <- paste(as.character(captured), collapse = " ")
  expect_true(grepl("alice@example.com", hdrs))
  expect_false(grepl("carol@example.com", hdrs))
  expect_false(grepl("dave@example.com", hdrs))
})

test_that("mc_draft warns when thread_id is set", {
  local_mocked_bindings(
    gm_create_draft = function(msg) msg,
    .package = "gmailr"
  )
  expect_warning(
    mc_draft(
      html = "<p>hi</p>", to = "bob@example.com",
      subject = "Test", from = "alice@example.com",
      thread_id = "abc123"
    ),
    "will NOT appear in thread"
  )
})

test_that("mc_draft applies labels to the draft thread", {
  modify_args <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) list(message = list(threadId = "draft_tid")),
    .package = "gmailr"
  )
  local_mocked_bindings(
    mc_thread_modify = function(thread_id, add = NULL, remove = NULL,
                                create_missing = FALSE) {
      modify_args <<- list(thread_id = thread_id, add = add,
                           create_missing = create_missing)
      invisible(NULL)
    },
    .package = "mc"
  )
  res <- mc_draft(
    html = "<p>x</p>", to = "bob@example.com",
    subject = "draft labelled", from = "alice@example.com",
    labels = "project-x"
  )
  expect_equal(res, "draft_tid")
  expect_equal(modify_args$thread_id, "draft_tid")
  expect_equal(modify_args$add, "project-x")
  expect_true(modify_args$create_missing)
})

test_that("mc_draft attaches files", {
  tmp <- tempfile(fileext = ".txt")
  writeLines("hello", tmp)
  on.exit(unlink(tmp))
  captured <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured <<- msg
      list(message = list(threadId = "t3"))
    },
    .package = "gmailr"
  )
  mc_draft(
    html = "<p>x</p>", to = "bob@example.com",
    subject = "att", from = "alice@example.com",
    attachments = tmp
  )
  expect_false(is.null(captured))
})

test_that("mc_draft errors on missing attachment file", {
  expect_error(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "att", from = "alice@example.com",
      attachments = "/nonexistent/file.pdf"
    ),
    "not found"
  )
})

# Scheduling is inherently a send: send_at forces the send path. Keeping those
# arguments off mc_draft() is what makes "nothing here can send" true.
test_that("mc_draft rejects send_at and scheduler", {
  expect_error(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "x", from = "alice@example.com",
      send_at = 10
    ),
    "mc_send"
  )
  expect_error(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "x", from = "alice@example.com",
      scheduler = "auto"
    ),
    "mc_send"
  )
})

test_that("mc_draft rejects the removed draft and test arguments", {
  expect_error(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "x", from = "alice@example.com", draft = TRUE
    )
  )
  expect_error(
    mc_draft(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "x", from = "alice@example.com", test = TRUE
    )
  )
})
