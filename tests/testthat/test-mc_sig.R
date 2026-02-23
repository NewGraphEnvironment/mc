test_that("mc_sig returns bundled signature by default", {
  sig <- mc_sig()
  expect_type(sig, "character")
  expect_match(sig, "Al Irvine")
  expect_match(sig, "250-777-1518")
  expect_match(sig, "newgraphenvironment.com")
})

test_that("mc_sig reads a custom signature file", {
  tmp <- tempfile(fileext = ".html")
  writeLines("<br>Jane Doe<br>Acme Corp", tmp)

  sig <- mc_sig(path = tmp)
  expect_match(sig, "Jane Doe")
  expect_match(sig, "Acme Corp")
  expect_false(grepl("Al Irvine", sig))

  unlink(tmp)
})

test_that("mc_sig errors on missing custom path", {
  expect_error(mc_sig(path = "/nonexistent/sig.html"), "Signature file not found")
})
