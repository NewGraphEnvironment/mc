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

test_that("mc_preview renders frontmatter header when given .md path", {
  draft <- tempfile(fileext = ".md")
  writeLines(c(
    "---",
    "to: cindy@x.com",
    "cc: [a@x.com, b@x.com]",
    "subject: Newsletter draft",
    "thread_id: t1",
    "attachments: [/tmp/x.pdf]",
    "---",
    "Hi Cindy,",
    "",
    "Body here."
  ), draft)
  tmp <- tempfile(fileext = ".html")
  mc_preview(draft, path = tmp, open = FALSE)
  html <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("cindy@x.com", html))
  expect_true(grepl("a@x.com, b@x.com", html))
  expect_true(grepl("Newsletter draft", html))
  expect_true(grepl("t1", html))
  expect_true(grepl("/tmp/x.pdf", html))
  expect_true(grepl("Body here", html))
})

test_that("mc_preview .md path without frontmatter still renders body", {
  draft <- tempfile(fileext = ".md")
  writeLines(c("Just a body", "no frontmatter here"), draft)
  tmp <- tempfile(fileext = ".html")
  mc_preview(draft, path = tmp, open = FALSE)
  html <- paste(readLines(tmp), collapse = "\n")
  # empty frontmatter renders em-dash in required rows
  expect_true(grepl("Subject", html))
  expect_true(grepl("\u2014", html))
  expect_true(grepl("Just a body", html))
})

test_that("mc_preview .md path escapes HTML in frontmatter values", {
  draft <- tempfile(fileext = ".md")
  writeLines(c(
    "---",
    "to: a@x.com",
    "subject: \"<script>alert(1)</script>\"",
    "---",
    "body"
  ), draft)
  tmp <- tempfile(fileext = ".html")
  mc_preview(draft, path = tmp, open = FALSE)
  html <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("&lt;script&gt;", html))
  expect_false(grepl("<script>alert", html))
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
