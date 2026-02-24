test_that("mc_send errors without path or html", {
  expect_error(
    mc_send(to = "test@test.com", subject = "test"),
    "Provide either"
  )
})

test_that("resolve_send_at converts minutes to seconds", {
  delay <- mc:::resolve_send_at(5)
  expect_equal(delay, 300)
})

test_that("resolve_send_at converts POSIXct to seconds", {
  future <- Sys.time() + 120
  delay <- mc:::resolve_send_at(future)
  expect_true(delay > 0 && delay <= 120)
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
