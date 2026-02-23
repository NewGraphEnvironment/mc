test_that("mc_sig returns HTML with signature content", {
  sig <- mc_sig()
  expect_type(sig, "character")
  expect_match(sig, "Al Irvine")
  expect_match(sig, "250-777-1518")
  expect_match(sig, "newgraphenvironment.com")
})
