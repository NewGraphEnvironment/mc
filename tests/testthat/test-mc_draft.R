# mc_draft() can only draft. The whole point of the split (#39) is that no
# argument reaches gm_send_message() from here, so several of these tests mock
# gm_send_message() to stop() and assert the call still succeeds.

test_that("mc_draft errors without path or html", {
  # No sender configured, as on a CI runner: the argument error must still be
  # the one reported, not the sender lookup (#47).
  withr::local_options(mc.from = NULL)
  withr::local_envvar(MC_FROM = NA)
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
  expect_equal(res$thread_id, "draft_thread_001")
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
  expect_equal(res$thread_id, "draft_tid")
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

# --- Draft id: returned, and used to replace that draft in place (#51) -------

draft_resource <- function(draft_id, thread_id = "t1", message_id = "m1") {
  list(id = draft_id, message = list(id = message_id, threadId = thread_id))
}

test_that("mc_draft returns the draft id, thread id and message id", {
  local_mocked_bindings(
    gm_create_draft = function(msg) draft_resource("r1"),
    .package = "gmailr"
  )
  local_mocked_bindings(
    gmail_draft_request = function(...) stop("a plain draft goes through gm_create_draft")
  )
  res <- suppressMessages(mc_draft(
    html = "<p>x</p>", to = "bob@example.com", subject = "s",
    from = "alice@example.com", sig = FALSE
  ))
  expect_equal(res, list(draft_id = "r1", thread_id = "t1", message_id = "m1"))
})

test_that("mc_draft(draft_id = ) replaces that draft and keeps its id", {
  env <- new.env()
  local_mocked_bindings(
    gm_create_draft = function(msg) stop("replacing must not create a draft"),
    gm_send_message = function(...) stop("mc_draft must never send"),
    .package = "gmailr"
  )
  local_mocked_bindings(
    gmail_draft_request = function(raw, thread_id = NULL, draft_id = NULL) {
      env$raw <- raw
      env$draft_id <- draft_id
      draft_resource(draft_id, message_id = "m2")
    }
  )
  expect_message(
    res <- mc_draft(html = "<p>new body</p>", to = "bob@example.com",
                    subject = "Edited", from = "alice@example.com", sig = FALSE,
                    draft_id = "r1"),
    "Draft r1 updated"
  )
  expect_equal(env$draft_id, "r1")
  expect_match(env$raw, "Subject: Edited", fixed = TRUE)
  expect_equal(res$draft_id, "r1")
  expect_equal(res$message_id, "m2")
})

test_that("a draft_id Gmail no longer has warns and creates a new draft", {
  local_mocked_bindings(
    gm_create_draft = function(msg) draft_resource("r2"),
    .package = "gmailr"
  )
  local_mocked_bindings(
    gmail_draft_request = function(raw, thread_id = NULL, draft_id = NULL) {
      stop(structure(class = c("mc_draft_not_found", "error", "condition"),
                     list(message = "Draft not found: r1", call = NULL)))
    }
  )
  expect_warning(
    res <- suppressMessages(mc_draft(
      html = "<p>x</p>", to = "bob@example.com", subject = "s",
      from = "alice@example.com", sig = FALSE, draft_id = "r1"
    )),
    "r1 was not found"
  )
  expect_equal(res$draft_id, "r2")
})

test_that("an error other than not-found on replace is not swallowed", {
  local_mocked_bindings(
    gm_create_draft = function(msg) stop("must not fall back to creating"),
    .package = "gmailr"
  )
  local_mocked_bindings(
    gmail_draft_request = function(...) stop("HTTP 500")
  )
  expect_error(
    suppressMessages(mc_draft(
      html = "<p>x</p>", to = "bob@example.com", subject = "s",
      from = "alice@example.com", sig = FALSE, draft_id = "r1"
    )),
    "HTTP 500"
  )
})

test_that("mc_draft rejects a draft_id that is not a string", {
  expect_error(
    mc_draft(html = "<p>x</p>", to = "bob@example.com", subject = "s",
             from = "alice@example.com", draft_id = 1),
    "draft_id"
  )
})

test_that("gmail_draft_request PUTs the draft resource to drafts/{id}", {
  env <- new.env()
  local_mocked_bindings(gm_token = function() NULL, .package = "gmailr")
  local_mocked_bindings(
    PUT = function(url, body, ...) {
      env$url <- url
      env$body <- jsonlite::fromJSON(body)
      structure(list(status_code = 200L), class = "fake_response")
    },
    POST = function(...) stop("an update must not POST"),
    status_code = function(x) x$status_code,
    stop_for_status = function(x, ...) invisible(x),
    content = function(x, ...) draft_resource("r1"),
    .package = "httr"
  )
  res <- gmail_draft_request("Subject: x\r\n\r\nhi", draft_id = "r1")
  expect_equal(env$url, "https://www.googleapis.com/gmail/v1/users/me/drafts/r1")
  expect_equal(env$body$id, "r1")
  expect_equal(rawToChar(jsonlite::base64url_dec(env$body$message$raw)),
               "Subject: x\r\n\r\nhi")
  expect_null(env$body$message$threadId)
  expect_equal(res$id, "r1")
})

test_that("gmail_draft_request turns a 404 on update into mc_draft_not_found", {
  local_mocked_bindings(gm_token = function() NULL, .package = "gmailr")
  local_mocked_bindings(
    PUT = function(...) structure(list(status_code = 404L), class = "fake_response"),
    status_code = function(x) x$status_code,
    .package = "httr"
  )
  expect_error(gmail_draft_request("raw", draft_id = "gone"),
               class = "mc_draft_not_found")
})

test_that("base64url_padded matches the encoding gmailr gives a send", {
  for (s in c("a", "ab", "abc", strrep("Subject: x\r\né?>~", 300))) {
    expect_identical(base64url_padded(s), gmailr:::base64url_encode(s))
  }
})
