test_that("mc_message_find rejects bad input", {
  expect_error(mc_message_find(query = 1))
  expect_error(mc_message_find(query = "x", n = "ten"))
  expect_error(mc_message_find(query = "x", status = "nope"))
})

make_msg <- function(id, thread, from, to, subj, date) {
  list(
    id = id,
    threadId = thread,
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

test_that("mc_message_find returns draft rows when status=draft", {
  draft_msg <- make_msg("d1", "t2", "a@x.com", "c@x.com", "draft",
                        "Tue, 2 Jan 2026 00:00:00 +0000")
  mockery::stub(mc_message_find, "gmailr::gm_drafts",
                list(list(drafts = list(list(id = "d1")))))
  mockery::stub(mc_message_find, "gmailr::gm_draft",
                list(message = draft_msg))
  result <- mc_message_find("draft", status = "draft")
  expect_equal(nrow(result), 1)
  expect_equal(result$status, "draft")
  expect_equal(result$thread_id, "t2")
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
