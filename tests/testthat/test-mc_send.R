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
