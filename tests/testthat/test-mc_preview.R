test_that("mc_preview rejects bad input", {
  expect_error(mc_preview(html = 1))
  expect_error(mc_preview(html = "<p>hi</p>", open = "yes"))
})

test_that("mc_preview writes file and returns path invisibly", {
  tmp <- tempfile(fileext = ".html")
  path <- mc_preview("<p>hi</p>", path = tmp, open = FALSE)
  expect_true(file.exists(path))
  expect_equal(path, tmp)
  expect_equal(readLines(path), "<p>hi</p>")
})

test_that("mc_preview creates parent directory if missing", {
  tmp <- file.path(tempfile(), "sub", "preview.html")
  path <- mc_preview("<p>hi</p>", path = tmp, open = FALSE)
  expect_true(file.exists(path))
})

test_that("mc_preview calls browseURL when open=TRUE", {
  called <- NULL
  mockery::stub(mc_preview, "utils::browseURL",
                function(url) called <<- url)
  tmp <- tempfile(fileext = ".html")
  path <- mc_preview("<p>hi</p>", path = tmp, open = TRUE)
  expect_equal(called, path)
})

test_that("mc_preview default path is under R_user_dir and persists", {
  cache_root <- tempfile()
  withr::with_envvar(c(R_USER_CACHE_DIR = cache_root), {
    expected <- file.path(tools::R_user_dir("mc", "cache"), "preview.html")
    mockery::stub(mc_preview, "utils::browseURL", function(url) NULL)
    path <- mc_preview("<p>hi</p>")
    expect_equal(path, expected)
    expect_true(file.exists(path))
    expect_true(startsWith(path, cache_root))
  })
})
