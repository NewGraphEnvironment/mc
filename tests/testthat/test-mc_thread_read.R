test_that("mc_thread_read rejects bad types", {
  expect_error(mc_thread_read(thread_id = 123))
  expect_error(mc_thread_read(thread_id = NULL))
})

test_that("mc_thread_read rejects bad drafts param", {
  expect_error(mc_thread_read(thread_id = "abc", drafts = "yes"))
  expect_error(mc_thread_read(thread_id = "abc", drafts = 1))
})

test_that("mc_thread_read without drafts has no status column", {
  # Mock gm_thread to return one message
  mock_msg <- list(
    payload = list(
      mimeType = "text/plain",
      body = list(
        size = 5,
        data = jsonlite::base64url_enc(charToRaw("Hello"))
      ),
      headers = list(
        list(name = "From", value = "test@test.com"),
        list(name = "Date", value = "Mon, 1 Jan 2026 00:00:00 +0000"),
        list(name = "Subject", value = "Test")
      )
    )
  )
  mockery::stub(mc_thread_read, "gmailr::gm_thread",
    list(messages = list(mock_msg)))
  result <- mc_thread_read("fake_id")
  expect_equal(names(result), c("from", "date", "subject", "body"))
  expect_false("status" %in% names(result))
})

test_that("mc_thread_read with drafts=TRUE adds status column", {
  mock_msg <- list(
    payload = list(
      mimeType = "text/plain",
      body = list(
        size = 5,
        data = jsonlite::base64url_enc(charToRaw("Hello"))
      ),
      headers = list(
        list(name = "From", value = "test@test.com"),
        list(name = "Date", value = "Mon, 1 Jan 2026 00:00:00 +0000"),
        list(name = "Subject", value = "Test")
      )
    )
  )
  mockery::stub(mc_thread_read, "gmailr::gm_thread",
    list(messages = list(mock_msg)))
  mockery::stub(mc_thread_read, "fetch_thread_drafts", list())
  result <- mc_thread_read("fake_id", drafts = TRUE)
  expect_true("status" %in% names(result))
  expect_equal(result$status, "sent")
})

test_that("mc_thread_read with drafts=TRUE includes draft messages", {
  mock_sent <- list(
    payload = list(
      mimeType = "text/plain",
      body = list(
        size = 4,
        data = jsonlite::base64url_enc(charToRaw("sent"))
      ),
      headers = list(
        list(name = "From", value = "al@test.com"),
        list(name = "Date", value = "Mon, 1 Jan 2026 00:00:00 +0000"),
        list(name = "Subject", value = "Test thread")
      )
    )
  )
  mock_draft_row <- data.frame(
    from = "al@test.com",
    date = "Tue, 2 Jan 2026 00:00:00 +0000",
    subject = "Re: Test thread",
    body = "draft reply",
    status = "draft",
    stringsAsFactors = FALSE
  )
  mockery::stub(mc_thread_read, "gmailr::gm_thread",
    list(messages = list(mock_sent)))
  mockery::stub(mc_thread_read, "fetch_thread_drafts", list(mock_draft_row))
  result <- mc_thread_read("fake_id", drafts = TRUE)
  expect_equal(nrow(result), 2)
  expect_equal(result$status, c("sent", "draft"))
  expect_equal(result$body, c("sent", "draft reply"))
})

test_that("mc_thread_read empty thread with drafts=FALSE returns empty df", {
  mockery::stub(mc_thread_read, "gmailr::gm_thread",
    list(messages = NULL))
  result <- mc_thread_read("fake_id", drafts = FALSE)
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("from", "date", "subject", "body"))
})

test_that("mc_thread_read empty thread with drafts=TRUE returns empty df with status", {
  mockery::stub(mc_thread_read, "gmailr::gm_thread",
    list(messages = NULL))
  mockery::stub(mc_thread_read, "fetch_thread_drafts", list())
  result <- mc_thread_read("fake_id", drafts = TRUE)
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("from", "date", "subject", "body", "status"))
})

test_that("extract_body finds plain text in simple payload", {
  payload <- list(
    mimeType = "text/plain",
    body = list(
      size = 5,
      data = jsonlite::base64url_enc(charToRaw("Hello"))
    )
  )
  expect_equal(mc:::extract_body(payload, "text/plain"), "Hello")
})

test_that("extract_body recurses into nested multipart", {
  payload <- list(
    mimeType = "multipart/related",
    body = list(size = 0),
    parts = list(
      list(
        mimeType = "multipart/alternative",
        body = list(size = 0),
        parts = list(
          list(
            mimeType = "text/plain",
            body = list(
              size = 11,
              data = jsonlite::base64url_enc(charToRaw("nested body"))
            )
          ),
          list(
            mimeType = "text/html",
            body = list(
              size = 20,
              data = jsonlite::base64url_enc(charToRaw("<p>nested body</p>"))
            )
          )
        )
      ),
      list(
        mimeType = "image/jpeg",
        body = list(size = 1000, data = "fakedata")
      )
    )
  )
  expect_equal(mc:::extract_body(payload, "text/plain"), "nested body")
  expect_equal(mc:::extract_body(payload, "text/html"), "<p>nested body</p>")
})

test_that("extract_body returns empty string when type not found", {
  payload <- list(
    mimeType = "text/html",
    body = list(
      size = 6,
      data = jsonlite::base64url_enc(charToRaw("<b>hi</b>"))
    )
  )
  expect_equal(mc:::extract_body(payload, "text/plain"), "")
})

test_that("extract_body handles NULL payload", {
  expect_equal(mc:::extract_body(NULL, "text/plain"), "")
})

test_that("extract_header returns value for matching header", {
  msg <- list(payload = list(headers = list(
    list(name = "From", value = "al@test.com"),
    list(name = "Subject", value = "Test subject")
  )))
  expect_equal(mc:::extract_header(msg, "From"), "al@test.com")
  expect_equal(mc:::extract_header(msg, "Subject"), "Test subject")
})

test_that("extract_header returns NA for missing header", {
  msg <- list(payload = list(headers = list(
    list(name = "From", value = "al@test.com")
  )))
  expect_equal(mc:::extract_header(msg, "Cc"), NA_character_)
})

test_that("extract_header handles NULL headers", {
  msg <- list(payload = list(headers = NULL))
  expect_equal(mc:::extract_header(msg, "From"), NA_character_)
})
