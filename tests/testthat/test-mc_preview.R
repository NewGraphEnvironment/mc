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

test_that("mc_preview shows frontmatter inline images in the body and the envelope", {
  img <- tempfile(fileext = ".png")
  writeBin(as.raw(1:10), img)
  draft <- tempfile(fileext = ".md")
  writeLines(c("---", "to: a@b.com", "subject: s", "inline_images:", paste0("  card: ", img),
               "---", "", "![card](cid:card)"), draft)
  tmp <- tempfile(fileext = ".html")
  mc_preview(draft, path = tmp, open = FALSE)
  out <- paste(readLines(tmp), collapse = "\n")
  expect_false(grepl("cid:card", out, fixed = TRUE))
  expect_match(out, paste0('src="file://', normalizePath(img), '"'), fixed = TRUE)
  expect_match(out, ">Inline</th>", fixed = TRUE)
})

test_that("a preview image path is percent-encoded into its file URL", {
  dir <- file.path(withr::local_tempdir(), "My Drive #1")
  dir.create(dir)
  img <- file.path(dir, "fig 100%.png")
  writeBin(as.raw(1:10), img)
  out <- mc:::preview_inline_images('<img src="cid:card">', list(card = img))
  url <- sub('.*src="([^"]*)".*', "\\1", out)
  expect_match(url, "^file:///")
  expect_false(grepl("[ #%]1|[ #]", sub("%[0-9A-F]{2}", "", url)))
  expect_identical(utils::URLdecode(sub("^file://", "", url)), normalizePath(img, winslash = "/"))
})

test_that("a path segment that already holds %xx is still encoded", {
  dir <- withr::local_tempdir()
  img <- file.path(dir, 'fig "v2" 10%ab \\1.png')
  writeBin(as.raw(1:10), img)
  url <- mc:::file_url(img)
  expect_false(grepl('[ "\\\\]', url))
  expect_identical(utils::URLdecode(sub("^file://", "", url)), normalizePath(img, winslash = "/"))
  out <- mc:::preview_inline_images('<img src="cid:card">', list(card = img))
  expect_identical(out, paste0('<img src="', url, '">'))
})

test_that("the preview rewrites only the references a send checks", {
  img <- tempfile(fileext = ".png")
  writeBin(as.raw(1:10), img)
  html <- paste0('<p><code>src=cid:card</code></p><img data-src="cid:card">',
                 '<img alt="a > b" src="cid:card"><td style="background: url(\'cid:card\')">')
  out <- mc:::preview_inline_images(html, list(card = img))
  url <- mc:::file_url(img)
  expect_match(out, "<code>src=cid:card</code>", fixed = TRUE)
  expect_match(out, 'data-src="cid:card"', fixed = TRUE)
  expect_match(out, paste0('alt="a > b" src="', url, '"'), fixed = TRUE)
  expect_match(out, paste0("url('", url, "')"), fixed = TRUE)
})

test_that("the preview rewrites images in a body that is not valid UTF-8", {
  img <- tempfile(fileext = ".png")
  writeBin(as.raw(1:10), img)
  html <- paste0('<img src="cid:card"><p>caf', rawToChar(as.raw(0xe9)), "</p>")
  out <- suppressWarnings(mc:::preview_inline_images(html, list(card = img)))
  expect_match(out, mc:::file_url(img), fixed = TRUE)
})
