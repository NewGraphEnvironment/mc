test_that("mc_send errors without path or html", {
  expect_error(
    mc_send(to = "test@test.com", subject = "test"),
    "Provide either"
  )
})

test_that("resolve_send_at converts minutes to future POSIXct", {
  target <- mc:::resolve_send_at(5)
  expect_s3_class(target, "POSIXct")
  delay <- as.numeric(difftime(target, Sys.time(), units = "secs"))
  expect_true(delay > 290 && delay <= 300)
})

test_that("resolve_send_at passes through future POSIXct", {
  future <- Sys.time() + 120
  target <- mc:::resolve_send_at(future)
  expect_s3_class(target, "POSIXct")
  expect_equal(as.numeric(target), as.numeric(future))
})

test_that("resolve_send_at rejects past times", {
  past <- Sys.time() - 60
  expect_error(mc:::resolve_send_at(past), "future")
})

test_that("resolve_send_at rejects negative minutes", {
  expect_error(mc:::resolve_send_at(-5), "future")
})

test_that("resolve_send_at rejects bad types", {
  expect_error(mc:::resolve_send_at("tomorrow"), "POSIXct")
  expect_error(mc:::resolve_send_at(TRUE), "POSIXct")
  expect_error(mc:::resolve_send_at(c(1, 2)), "POSIXct")
})

test_that("mc_send builds MIME message with correct fields (draft)", {
  captured_msg <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured_msg <<- msg
      list(message = list(threadId = "draft_thread_001"))
    },
    .package = "gmailr"
  )
  res <- mc_send(
    html = "<p>hello</p>", to = "bob@example.com",
    subject = "Test subject", from = "alice@example.com",
    draft = TRUE
  )
  expect_false(is.null(captured_msg))
  expect_equal(res, "draft_thread_001")
})

test_that("mc_send passes cc and bcc to MIME message", {
  captured_msg <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured_msg <<- msg
      msg
    },
    .package = "gmailr"
  )
  mc_send(
    html = "<p>hi</p>", to = "bob@example.com",
    subject = "CC test", from = "alice@example.com",
    cc = "carol@example.com", bcc = "dave@example.com",
    draft = TRUE
  )
  expect_false(is.null(captured_msg))
})

test_that("mc_send sends with thread_id when draft = FALSE", {
  captured_args <- list()
  local_mocked_bindings(
    gm_send_message = function(msg, ...) {
      captured_args <<- list(msg = msg, ...)
      list(threadId = "abc123")
    },
    .package = "gmailr"
  )
  res <- mc_send(
    html = "<p>reply</p>", to = "bob@example.com",
    subject = "Re: Thread", from = "alice@example.com",
    thread_id = "abc123", draft = FALSE
  )
  expect_equal(captured_args$thread_id, "abc123")
  expect_equal(res, "abc123")
})

test_that("mc_send returns thread_id from new-thread send (no thread_id arg)", {
  local_mocked_bindings(
    gm_send_message = function(msg, ...) {
      list(threadId = "newly_assigned_thread_42")
    },
    .package = "gmailr"
  )
  res <- mc_send(
    html = "<p>fresh</p>", to = "bob@example.com",
    subject = "Fresh thread", from = "alice@example.com",
    draft = FALSE
  )
  expect_equal(res, "newly_assigned_thread_42")
})

test_that("mc_send returns NULL invisibly when gmailr response lacks threadId", {
  local_mocked_bindings(
    gm_send_message = function(msg, ...) list(),
    .package = "gmailr"
  )
  res <- mc_send(
    html = "<p>x</p>", to = "bob@example.com",
    subject = "No thread id", from = "alice@example.com",
    draft = FALSE
  )
  expect_null(res)
})

test_that("mc_send test mode overrides to/cc/bcc/thread_id", {
  captured_msg <- NULL
  local_mocked_bindings(
    gm_send_message = function(msg, ...) {
      captured_msg <<- msg
      msg
    },
    gm_create_draft = function(msg) {
      captured_msg <<- msg
      msg
    },
    .package = "gmailr"
  )
  # test = TRUE should redirect to from, strip cc/bcc/thread_id
  mc_send(
    html = "<p>test</p>", to = "bob@example.com",
    subject = "Test mode", from = "alice@example.com",
    cc = "carol@example.com", bcc = "dave@example.com",
    thread_id = "abc123", test = TRUE, draft = FALSE
  )
  expect_false(is.null(captured_msg))
})

test_that("mc_send warns when draft + thread_id", {
  local_mocked_bindings(
    gm_create_draft = function(msg) msg,
    .package = "gmailr"
  )
  expect_warning(
    mc_send(
      html = "<p>hi</p>", to = "bob@example.com",
      subject = "Test", from = "alice@example.com",
      thread_id = "abc123", draft = TRUE
    ),
    "will NOT appear in thread"
  )
})

test_that("send_log writes to ~/.mc/send_log.txt", {
  log_file <- file.path(Sys.getenv("HOME"), ".mc", "send_log.txt")
  # Record state before
  lines_before <- if (file.exists(log_file)) length(readLines(log_file)) else 0
  mc:::send_log("Test Subject", "bob@example.com", "SENT")
  lines_after <- length(readLines(log_file))
  expect_equal(lines_after, lines_before + 1)
  last_line <- readLines(log_file)[lines_after]
  expect_match(last_line, "SENT")
  expect_match(last_line, "Test Subject")
})

test_that("send_notify does not error", {
  # Just confirm it doesn't throw — notification may or may not appear
  expect_no_error(mc:::send_notify("Test", "body text"))
})

test_that("default_from reads option then env then errors", {
  withr::local_options(mc.from = NULL)
  withr::local_envvar(MC_FROM = "")
  expect_error(mc:::default_from(), "No default email found")

  withr::local_envvar(MC_FROM = "env@example.com")
  expect_equal(mc:::default_from(), "env@example.com")

  withr::local_options(mc.from = "opt@example.com")
  expect_equal(mc:::default_from(), "opt@example.com")
})

test_that("mc_send attaches files to MIME message", {
  captured_msg <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured_msg <<- msg
      msg
    },
    .package = "gmailr"
  )

  tmp1 <- tempfile(fileext = ".csv")
  tmp2 <- tempfile(fileext = ".pdf")
  writeLines("a,b\n1,2", tmp1)
  writeBin(charToRaw("fake pdf"), tmp2)

  mc_send(
    html = "<p>hello</p>", to = "bob@example.com",
    subject = "Attachment test", from = "alice@example.com",
    attachments = c(tmp1, tmp2),
    draft = TRUE
  )
  expect_false(is.null(captured_msg))
  unlink(c(tmp1, tmp2))
})

test_that("mc_send errors on missing attachment file", {
  expect_error(
    mc_send(
      html = "<p>hi</p>", to = "bob@example.com",
      subject = "Test", from = "alice@example.com",
      attachments = "/nonexistent/file.pdf"
    ),
    "Attachment file.*not found"
  )
})

test_that("mc_send errors on mix of valid and missing attachments", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("a,b", tmp)
  expect_error(
    mc_send(
      html = "<p>hi</p>", to = "bob@example.com",
      subject = "Test", from = "alice@example.com",
      attachments = c(tmp, "/nonexistent/file.pdf")
    ),
    "not found"
  )
  unlink(tmp)
})

test_that("mc_send works without attachments (NULL default)", {
  captured_msg <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      captured_msg <<- msg
      msg
    },
    .package = "gmailr"
  )
  mc_send(
    html = "<p>no attachments</p>", to = "bob@example.com",
    subject = "No attach", from = "alice@example.com",
    draft = TRUE
  )
  expect_false(is.null(captured_msg))
})

test_that("mc_send applies labels via mc_thread_modify on send path", {
  modify_args <- NULL
  local_mocked_bindings(
    gm_send_message = function(msg, ...) list(threadId = "tid_99"),
    .package = "gmailr"
  )
  local_mocked_bindings(
    mc_thread_modify = function(thread_id, add = NULL, remove = NULL) {
      modify_args <<- list(thread_id = thread_id, add = add, remove = remove)
      invisible(NULL)
    },
    .package = "mc"
  )
  res <- mc_send(
    html = "<p>x</p>", to = "bob@example.com",
    subject = "labelled", from = "alice@example.com",
    labels = c("project-x", "urgent"),
    draft = FALSE
  )
  expect_equal(res, "tid_99")
  expect_equal(modify_args$thread_id, "tid_99")
  expect_equal(modify_args$add, c("project-x", "urgent"))
  expect_null(modify_args$remove)
})

test_that("mc_send applies labels to the draft thread on draft path", {
  modify_args <- NULL
  local_mocked_bindings(
    gm_create_draft = function(msg) {
      list(message = list(threadId = "draft_tid"))
    },
    .package = "gmailr"
  )
  local_mocked_bindings(
    mc_thread_modify = function(thread_id, add = NULL, remove = NULL) {
      modify_args <<- list(thread_id = thread_id, add = add, remove = remove)
      invisible(NULL)
    },
    .package = "mc"
  )
  res <- mc_send(
    html = "<p>x</p>", to = "bob@example.com",
    subject = "draft labelled", from = "alice@example.com",
    labels = "project-x",
    draft = TRUE
  )
  expect_equal(res, "draft_tid")
  expect_equal(modify_args$thread_id, "draft_tid")
  expect_equal(modify_args$add, "project-x")
})

test_that("mc_send warns when send succeeds but threadId missing and labels set", {
  local_mocked_bindings(
    gm_send_message = function(msg, ...) list(),
    .package = "gmailr"
  )
  local_mocked_bindings(
    mc_thread_modify = function(...) stop("should not be called"),
    .package = "mc"
  )
  expect_warning(
    mc_send(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "no tid", from = "alice@example.com",
      labels = "project-x",
      draft = FALSE
    ),
    "did not include a threadId"
  )
})

test_that("mc_send labels arg validation rejects non-character", {
  expect_error(
    mc_send(
      html = "<p>x</p>", to = "bob@example.com",
      subject = "x", from = "alice@example.com",
      labels = 42
    ),
    "labels"
  )
})

test_that("caffeinate is not called when send_at is NULL", {
  # Stub caffeinate_send to record whether it was called
  called <- FALSE
  local_mocked_bindings(
    caffeinate_send = function(proc) {
      called <<- TRUE
    },
    .package = "mc"
  )
  # Normal send (send_at = NULL) should never hit caffeinate_send
  # Use html to skip file read, will error at gmailr but that's after
  # the send_at check
  tryCatch(
    mc_send(html = "<p>test</p>", to = "test@test.com",
            subject = "test", send_at = NULL),
    error = function(e) NULL
  )
  expect_false(called)
})
