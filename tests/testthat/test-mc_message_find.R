test_that("mc_message_find rejects bad input", {
  expect_error(mc_message_find(query = 1))
  expect_error(mc_message_find(query = "x", n = "ten"))
  expect_error(mc_message_find(query = "x", status = "nope"))
})

make_msg <- function(id, thread, from, to, subj, date, labels = "SENT") {
  list(
    id = id,
    threadId = thread,
    labelIds = labels,
    payload = list(headers = list(
      list(name = "From", value = from),
      list(name = "To", value = to),
      list(name = "Subject", value = subj),
      list(name = "Date", value = date)
    ))
  )
}

test_that("mc_message_find returns sent rows", {
  msg <- make_msg("m1", "t1", "a@x.com", "b@x.com", "hi",
                  "Mon, 1 Jan 2026 00:00:00 +0000")
  mockery::stub(mc_message_find, "gmailr::gm_messages", list())
  mockery::stub(mc_message_find, "gmailr::gm_id", "m1")
  mockery::stub(mc_message_find, "gmailr::gm_message", msg)
  result <- mc_message_find("hi", status = "sent")
  expect_equal(nrow(result), 1)
  expect_equal(result$message_id, "m1")
  expect_equal(result$status, "sent")
  expect_equal(result$to, "b@x.com")
})

# Mocks gm_messages()/gm_id()/gm_message() over a set of messages, recording
# every search string Gmail would receive (#50).
mock_search <- function(env, msgs) {
  env$searches <- character()
  local_mocked_bindings(
    gm_messages = function(search = NULL, num_results = NULL, ...) {
      env$searches <- c(env$searches, search)
      env$num_results <- num_results
      list()
    },
    gm_id = function(x, ...) names(msgs),
    gm_message = function(id, ...) msgs[[id]],
    gm_drafts = function(...) stop("drafts must be searched, not listed"),
    gm_draft = function(...) stop("drafts must be searched, not listed"),
    .package = "gmailr",
    .env = parent.frame()
  )
}

test_that("mc_message_find(status = 'draft') passes the query and dates to Gmail", {
  env <- new.env()
  mock_search(env, list(d1 = make_msg("d1", "t2", "a@x.com", "c@x.com", "draft",
                                      "Tue, 2 Jan 2026 00:00:00 +0000",
                                      labels = "DRAFT")))
  result <- mc_message_find('subject:"Q3 report"', status = "draft",
                            after = "2026-01-01", before = "2026-02-01")
  expect_equal(env$searches,
               'subject:"Q3 report" after:2026/01/01 before:2026/02/01 in:drafts')
  expect_equal(nrow(result), 1)
  expect_equal(result$status, "draft")
  expect_equal(result$thread_id, "t2")
})

test_that("mc_message_find(status = 'sent') excludes drafts in the query", {
  env <- new.env()
  mock_search(env, list(m1 = make_msg("m1", "t1", "a@x.com", "b@x.com", "hi",
                                      "Mon, 1 Jan 2026 00:00:00 +0000")))
  mc_message_find("hi", status = "sent")
  expect_equal(env$searches, "hi -in:drafts")
})

test_that("mc_message_find(status = 'any') searches once and labels each row", {
  env <- new.env()
  mock_search(env, list(
    m1 = make_msg("m1", "t1", "a@x.com", "b@x.com", "hi",
                  "Mon, 1 Jan 2026 00:00:00 +0000", labels = c("SENT", "INBOX")),
    d1 = make_msg("d1", "t1", "a@x.com", "b@x.com", "Re: hi",
                  "Tue, 2 Jan 2026 00:00:00 +0000", labels = "DRAFT")
  ))
  result <- mc_message_find("hi", n = 7)
  expect_equal(env$searches, "hi")
  expect_equal(env$num_results, 7)
  # Most recent first
  expect_equal(result$message_id, c("d1", "m1"))
  expect_equal(result$status, c("draft", "sent"))
})

test_that("mc_message_find returns empty df with correct columns when no matches", {
  mockery::stub(mc_message_find, "gmailr::gm_messages", list())
  mockery::stub(mc_message_find, "gmailr::gm_id", character(0))
  mockery::stub(mc_message_find, "gmailr::gm_drafts",
                list(list(drafts = list())))
  suppressMessages(result <- mc_message_find("nothing"))
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("message_id", "thread_id", "from", "to",
                                "subject", "date", "status"))
})
