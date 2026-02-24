test_that("mc_thread_read rejects bad types", {
  expect_error(mc_thread_read(thread_id = 123))
  expect_error(mc_thread_read(thread_id = NULL))
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
