test_that("mc_thread_body_latest rejects bad input", {
  expect_error(mc_thread_body_latest(123))
  expect_error(mc_thread_body_latest("abc", strip_quotes = "yes"))
  expect_error(mc_thread_body_latest("abc", status = "other"))
})

test_that("strip_quoted removes > lines and 'On ... wrote:' attribution", {
  text <- paste(
    "Hi there,",
    "",
    "Here's the latest.",
    "",
    "On Mon, 1 Jan 2026 at 10:00, Person wrote:",
    "> quoted line 1",
    "> quoted line 2",
    sep = "\n"
  )
  out <- mc:::strip_quoted(text)
  expect_false(grepl("^>", out))
  expect_false(grepl("wrote:", out))
  expect_true(grepl("Here's the latest.", out))
})

test_that("strip_quoted passes through text without quotes", {
  expect_equal(mc:::strip_quoted("just a body"), "just a body")
})

test_that("mc_thread_body_latest returns last body stripped", {
  df <- data.frame(
    from = c("a", "b"),
    date = c("d1", "d2"),
    subject = c("s", "s"),
    body = c("first", "latest\n> quoted"),
    status = c("sent", "sent"),
    stringsAsFactors = FALSE
  )
  mockery::stub(mc_thread_body_latest, "mc_thread_read", df)
  out <- mc_thread_body_latest("tid")
  expect_equal(out, "latest")
})

test_that("mc_thread_body_latest with strip_quotes=FALSE keeps quotes", {
  df <- data.frame(
    from = "a", date = "d", subject = "s",
    body = "latest\n> quoted",
    status = "sent",
    stringsAsFactors = FALSE
  )
  mockery::stub(mc_thread_body_latest, "mc_thread_read", df)
  out <- mc_thread_body_latest("tid", strip_quotes = FALSE)
  expect_equal(out, "latest\n> quoted")
})

test_that("mc_thread_body_latest status filter selects from matching pool", {
  df <- data.frame(
    from = c("a", "b"),
    date = c("d1", "d2"),
    subject = c("s", "s"),
    body = c("sent body", "draft body"),
    status = c("sent", "draft"),
    stringsAsFactors = FALSE
  )
  mockery::stub(mc_thread_body_latest, "mc_thread_read", df)
  expect_equal(mc_thread_body_latest("tid", status = "sent"), "sent body")
  expect_equal(mc_thread_body_latest("tid", status = "draft"), "draft body")
})

test_that("mc_thread_body_latest returns empty string on empty thread", {
  empty <- data.frame(
    from = character(0), date = character(0), subject = character(0),
    body = character(0), status = character(0), stringsAsFactors = FALSE
  )
  mockery::stub(mc_thread_body_latest, "mc_thread_read", empty)
  expect_equal(mc_thread_body_latest("tid"), "")
})
