test_that("mc_preview rejects bad input", {
  expect_error(mc_preview(html = 1))
  expect_error(mc_preview(html = "<p>hi</p>", open = "yes"))
})

test_that("mc_preview writes file and returns path invisibly", {
  path <- mc_preview("<p>hi</p>", open = FALSE)
  expect_true(file.exists(path))
  expect_equal(tools::file_ext(path), "html")
  expect_equal(readLines(path), "<p>hi</p>")
})

test_that("mc_preview calls browseURL when open=TRUE", {
  called <- NULL
  mockery::stub(mc_preview, "utils::browseURL",
                function(url) called <<- url)
  path <- mc_preview("<p>hi</p>", open = TRUE)
  expect_equal(called, path)
})
