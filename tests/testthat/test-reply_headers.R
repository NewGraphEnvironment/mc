# Drafts and sends into a thread: the draft lands in the thread, and both carry
# In-Reply-To / References and a "Re: " subject (#55).

hdr_msg <- function(labels = "INBOX", ...) {
  h <- list(...)
  list(labelIds = labels,
       payload = list(headers = Map(function(n, v) list(name = n, value = v),
                                    names(h), unname(h))))
}

# A received message that is itself a reply, then a newer unsent draft.
reply_thread <- function() {
  list(messages = list(
    hdr_msg("INBOX", `Message-ID` = "<a@x>", References = "<z@x>"),
    hdr_msg("DRAFT", `Message-ID` = "<draft@x>")
  ))
}

mock_thread_draft <- function(env, thread = reply_thread(), returned_thread = "t9") {
  local_mocked_bindings(
    gm_thread = function(id, ...) {
      env$thread_read <- id
      thread
    },
    gm_create_draft = function(...) stop("a threaded draft cannot go through gm_create_draft"),
    gm_send_message = function(...) stop("mc_draft must never send"),
    .package = "gmailr", .env = parent.frame()
  )
  local_mocked_bindings(
    gmail_draft_request = function(raw, thread_id = NULL, draft_id = NULL) {
      env$raw <- raw
      env$thread_id <- thread_id
      env$draft_id <- draft_id
      list(id = draft_id %||% "r-new",
           message = list(id = "m", threadId = returned_thread))
    },
    .env = parent.frame()
  )
}

draft_into <- function(...) {
  mc_draft(html = "<p>reply</p>", to = "bob@example.com", subject = "Hello",
           from = "alice@example.com", sig = FALSE, thread_id = "t9", ...)
}

test_that("a draft with thread_id is created in that thread with reply headers", {
  env <- new.env()
  mock_thread_draft(env)
  expect_no_warning(res <- suppressMessages(draft_into()))
  expect_equal(env$thread_id, "t9")
  expect_null(env$draft_id)
  expect_match(env$raw, "In-Reply-To: <a@x>", fixed = TRUE)
  expect_match(env$raw, "References: <z@x> <a@x>", fixed = TRUE)
  expect_match(env$raw, "Subject: Re: Hello", fixed = TRUE)
  expect_equal(res$thread_id, "t9")
})

test_that("the latest message not a draft, trash or spam is the one answered", {
  env <- new.env()
  mock_thread_draft(env, thread = list(messages = list(
    hdr_msg("INBOX", `Message-Id` = "<first@x>"),
    hdr_msg("INBOX", `Message-Id` = "<second@x>", `In-Reply-To` = "<first@x>"),
    hdr_msg("TRASH", `Message-ID` = "<trashed@x>"),
    hdr_msg("SPAM", `Message-ID` = "<spam@x>"),
    hdr_msg("DRAFT", `Message-ID` = "<draft@x>")
  )))
  suppressMessages(draft_into())
  # Message-Id in any case; References falls back to the parent's In-Reply-To
  expect_match(env$raw, "In-Reply-To: <second@x>", fixed = TRUE)
  expect_match(env$raw, "References: <first@x> <second@x>", fixed = TRUE)
})

test_that("a subject already starting with Re: is left alone", {
  env <- new.env()
  mock_thread_draft(env)
  suppressMessages(mc_draft(html = "<p>x</p>", to = "bob@example.com",
                            subject = "RE: Hello", from = "alice@example.com",
                            sig = FALSE, thread_id = "t9"))
  expect_match(env$raw, "Subject: RE: Hello", fixed = TRUE)
  expect_false(grepl("Re: RE:", env$raw, fixed = TRUE))
})

test_that("a long References chain keeps the first id and the last ten", {
  env <- new.env()
  refs <- paste(sprintf("<%040d@mail.example.com>", 1:30), collapse = " ")
  mock_thread_draft(env, thread = list(messages = list(
    hdr_msg("INBOX", `Message-ID` = "<last@x>", References = refs)
  )))
  suppressMessages(draft_into())
  line <- regmatches(env$raw, regexpr("References: [^\r\n]*", env$raw))
  ids <- regmatches(line, gregexpr("<[^>]+>", line))[[1]]
  expect_length(ids, 11)
  expect_equal(ids[1], sprintf("<%040d@mail.example.com>", 1))
  expect_equal(ids[11], "<last@x>")
  expect_lt(nchar(line), 998)
})

test_that("replacing a threaded draft keeps the thread", {
  env <- new.env()
  mock_thread_draft(env)
  suppressMessages(draft_into(draft_id = "r1"))
  expect_equal(env$draft_id, "r1")
  expect_equal(env$thread_id, "t9")
})

test_that("a stale draft_id with thread_id re-creates the draft in the thread", {
  env <- new.env()
  mock_thread_draft(env)
  calls <- list()
  local_mocked_bindings(
    gmail_draft_request = function(raw, thread_id = NULL, draft_id = NULL) {
      calls[[length(calls) + 1]] <<- list(thread_id = thread_id, draft_id = draft_id)
      if (!is.null(draft_id)) {
        stop(structure(class = c("mc_draft_not_found", "error", "condition"),
                       list(message = "gone", call = NULL)))
      }
      list(id = "r2", message = list(id = "m", threadId = thread_id))
    }
  )
  expect_warning(res <- suppressMessages(draft_into(draft_id = "r1")), "not found")
  expect_equal(calls[[2]], list(thread_id = "t9", draft_id = NULL))
  expect_equal(res$draft_id, "r2")
})

test_that("a draft Gmail places in another thread warns", {
  env <- new.env()
  mock_thread_draft(env, returned_thread = "elsewhere")
  expect_warning(suppressMessages(draft_into()), "placed the draft in thread elsewhere")
})

test_that("a thread with no Message-ID warns and threads by id only", {
  env <- new.env()
  mock_thread_draft(env, thread = list(messages = list(hdr_msg("INBOX", Subject = "x"))))
  expect_warning(suppressMessages(draft_into()), "no message with a Message-ID")
  expect_equal(env$thread_id, "t9")
  expect_false(grepl("In-Reply-To", env$raw, fixed = TRUE))
})

test_that("an unreadable thread stops before anything is created or sent", {
  local_mocked_bindings(
    gm_thread = function(...) stop("HTTP 404"),
    gm_send_message = function(...) stop("must not send"),
    gm_create_draft = function(...) stop("must not draft"),
    .package = "gmailr"
  )
  local_mocked_bindings(gmail_draft_request = function(...) stop("must not draft"))
  expect_error(suppressMessages(draft_into()), "Could not read thread t9.*HTTP 404")
  expect_error(
    mc_send(html = "<p>x</p>", to = "bob@example.com", subject = "Hello",
            from = "alice@example.com", sig = FALSE, thread_id = "t9"),
    "Could not read thread t9"
  )
})

test_that("mc_send into a thread carries the reply headers too", {
  env <- new.env()
  local_mocked_bindings(
    gm_thread = function(id, ...) reply_thread(),
    gm_send_message = function(msg, thread_id = NULL, ...) {
      env$raw <- as.character(msg)
      env$thread_id <- thread_id
      list(threadId = thread_id)
    },
    .package = "gmailr"
  )
  local_mocked_bindings(gmail_draft_request = function(...) stop("mc_send must never draft"))
  suppressMessages(mc_send(html = "<p>x</p>", to = "bob@example.com",
                           subject = "Hello", from = "alice@example.com",
                           sig = FALSE, thread_id = "t9"))
  expect_equal(env$thread_id, "t9")
  expect_match(env$raw, "In-Reply-To: <a@x>", fixed = TRUE)
  expect_match(env$raw, "References: <z@x> <a@x>", fixed = TRUE)
  expect_match(env$raw, "Subject: Re: Hello", fixed = TRUE)
})

test_that("without thread_id nothing changes: no thread read, no headers, no Re:", {
  env <- new.env()
  local_mocked_bindings(
    gm_thread = function(...) stop("no thread to read"),
    gm_create_draft = function(msg, ...) {
      env$raw <- as.character(msg)
      list(id = "r1", message = list(id = "m", threadId = "t"))
    },
    .package = "gmailr"
  )
  local_mocked_bindings(gmail_draft_request = function(...) stop("plain drafts use gm_create_draft"))
  suppressMessages(mc_draft(html = "<p>x</p>", to = "bob@example.com", subject = "Hello",
                            from = "alice@example.com", sig = FALSE))
  expect_false(grepl("In-Reply-To|References", env$raw))
  expect_match(env$raw, "Subject: Hello", fixed = TRUE)
})

test_that("to_self drops the thread, so no thread read and no headers", {
  env <- new.env()
  local_mocked_bindings(
    gm_thread = function(...) stop("to_self must not read the thread"),
    gm_create_draft = function(msg, ...) {
      env$raw <- as.character(msg)
      list(id = "r1", message = list(id = "m", threadId = "t"))
    },
    .package = "gmailr"
  )
  suppressMessages(draft_into(to_self = TRUE))
  expect_false(grepl("In-Reply-To", env$raw, fixed = TRUE))
  expect_match(env$raw, "Subject: Hello", fixed = TRUE)
})

test_that("header values from the thread are copied only as well-formed msg-ids", {
  env <- new.env()
  mock_thread_draft(env, thread = list(messages = list(hdr_msg(
    "INBOX", `Message-ID` = "<a@x>\r\nBcc: evil@attacker.example",
    References = "<z@x> <b\r\nCc: evil2@attacker.example>"
  ))))
  expect_warning(suppressMessages(draft_into()), "no message with a Message-ID")
  expect_false(grepl("attacker", env$raw, fixed = TRUE))
  expect_false(grepl("In-Reply-To", env$raw, fixed = TRUE))

  # A good Message-ID with a References token that smuggles a line break:
  # the bad token is dropped, the good ones kept
  env2 <- new.env()
  mock_thread_draft(env2, thread = list(messages = list(hdr_msg(
    "INBOX", `Message-ID` = "<a@x>",
    References = "<z@x> <b\r\nCc: evil2@attacker.example>"
  ))))
  suppressMessages(draft_into())
  expect_false(grepl("attacker", env2$raw, fixed = TRUE))
  expect_match(env2$raw, "References: <z@x> <a@x>", fixed = TRUE)
})
