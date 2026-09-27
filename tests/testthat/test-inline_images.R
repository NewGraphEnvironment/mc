png_file <- function() {
  f <- tempfile(fileext = ".png")
  # smallest valid PNG: 1x1 transparent pixel
  writeBin(as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48,
                    0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
                    0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78,
                    0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
                    0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82)), f)
  f
}

capture_send <- function(env) {
  local_mocked_bindings(gm_send_message = function(msg, ...) { env$msg <- msg; list(threadId = "t1") },
                        .package = "gmailr", .env = parent.frame())
}

test_that("an inline image becomes an inline part with its Content-Id", {
  env <- new.env(); capture_send(env)
  img <- png_file()
  mc_send(html = '<p><img src="cid:card"></p>', to = "bob@example.com", subject = "x",
          from = "alice@example.com", sig = FALSE, inline_images = c(card = img))
  raw <- as.character(env$msg)
  expect_match(raw, "Content-Id: <card>", fixed = TRUE)
  expect_match(raw, "Content-Disposition: inline", fixed = TRUE)
  expect_match(raw, "image/png", fixed = TRUE)
})

test_that("inline images are kept under to_self, where cc and bcc are dropped", {
  env <- new.env(); capture_send(env)
  suppressMessages(mc_send(html = '<img src="cid:card">', to = "bob@example.com", subject = "x",
                           from = "alice@example.com", sig = FALSE, bcc = "dave@example.com",
                           to_self = TRUE, inline_images = c(card = png_file())))
  raw <- as.character(env$msg)
  expect_match(raw, "Content-Id: <card>", fixed = TRUE)
  expect_false(grepl("dave@example.com", raw, fixed = TRUE))
})

test_that("drafts carry inline images too", {
  env <- new.env()
  local_mocked_bindings(gm_create_draft = function(msg, ...) { env$msg <- msg; list(message = list(threadId = "t")) },
                        .package = "gmailr")
  suppressMessages(mc_draft(html = '<img src="cid:card">', to = "bob@example.com", subject = "x",
                            from = "alice@example.com", sig = FALSE, inline_images = c(card = png_file())))
  expect_match(as.character(env$msg), "Content-Id: <card>", fixed = TRUE)
})

test_that("argument checks: names, files, and cid references", {
  env <- new.env(); capture_send(env)
  send <- function(html, imgs) mc_send(html = html, to = "bob@example.com", subject = "x",
                                       from = "alice@example.com", sig = FALSE, inline_images = imgs)
  img <- png_file()
  expect_error(send('<img src="cid:a">', unname(img)), "must be named")
  expect_error(send('<img src="cid:a">', c(a = img, a = img)), "unique")
  expect_error(send('<img src="cid:bad name">', c(`bad name` = img)), "Invalid Content-ID")
  expect_error(send('<img src="cid:a">', c(a = tempfile())), "not found")
  expect_error(send('<img src="cid:b">', c(a = img)), "no matching inline image")
  expect_error(send('<img src="cid:a">', NULL), "no inline_images")
  expect_warning(send("<p>no image</p>", c(a = img)), "not referenced")
  expect_null(env$msg[["never-set"]])
})

test_that("a failed check sends nothing", {
  sent <- FALSE
  local_mocked_bindings(gm_send_message = function(...) { sent <<- TRUE; list(threadId = "t") }, .package = "gmailr")
  expect_error(mc_send(html = '<img src="cid:b">', to = "bob@example.com", subject = "x",
                       from = "alice@example.com", sig = FALSE, inline_images = c(a = png_file())))
  expect_false(sent)
})

test_that("frontmatter inline_images reach mc_send", {
  img <- png_file()
  md <- tempfile(fileext = ".md")
  writeLines(c("---", "to: bob@example.com", "subject: x", "inline_images:", paste0("  card: ", img),
               "---", "", '<img src="cid:card">'), md)
  args <- mc:::md_dispatch_args(md, to_self = FALSE, override = list())
  expect_identical(args$inline_images, c(card = img))
})
