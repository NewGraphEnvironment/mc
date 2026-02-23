test_that("mc_send errors without path or html", {
  expect_error(
    mc_send(to = "test@test.com", subject = "test"),
    "Provide either"
  )
})
