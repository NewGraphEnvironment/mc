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
  local_mocked_bindings(
    gm_send_message = function(msg, ...) {
      env$msg <- msg
      list(threadId = "t1")
    },
    .package = "gmailr", .env = parent.frame()
  )
}

test_that("an inline image becomes an inline part with its Content-Id", {
  env <- new.env()
  capture_send(env)
  img <- png_file()
  mc_send(html = '<p><img src="cid:card"></p>', to = "bob@example.com", subject = "x",
          from = "alice@example.com", sig = FALSE, inline_images = c(card = img))
  raw <- as.character(env$msg)
  expect_match(raw, "Content-Id: <card>", fixed = TRUE)
  expect_match(raw, "Content-Disposition: inline", fixed = TRUE)
  expect_match(raw, "image/png", fixed = TRUE)
})

test_that("inline images are kept under to_self, where cc and bcc are dropped", {
  env <- new.env()
  capture_send(env)
  suppressMessages(mc_send(html = '<img src="cid:card">', to = "bob@example.com", subject = "x",
                           from = "alice@example.com", sig = FALSE, bcc = "dave@example.com",
                           to_self = TRUE, inline_images = c(card = png_file())))
  raw <- as.character(env$msg)
  expect_match(raw, "Content-Id: <card>", fixed = TRUE)
  expect_false(grepl("dave@example.com", raw, fixed = TRUE))
})

test_that("drafts carry inline images too", {
  env <- new.env()
  local_mocked_bindings(
    gm_create_draft = function(msg, ...) {
      env$msg <- msg
      list(message = list(threadId = "t"))
    },
    .package = "gmailr"
  )
  suppressMessages(mc_draft(html = '<img src="cid:card">', to = "bob@example.com", subject = "x",
                            from = "alice@example.com", sig = FALSE, inline_images = c(card = png_file())))
  expect_match(as.character(env$msg), "Content-Id: <card>", fixed = TRUE)
})

test_that("argument checks: names, files, and cid references", {
  env <- new.env()
  capture_send(env)
  send <- function(html, imgs) {
    mc_send(html = html, to = "bob@example.com", subject = "x",
            from = "alice@example.com", sig = FALSE, inline_images = imgs)
  }
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
  local_mocked_bindings(
    gm_send_message = function(...) {
      sent <<- TRUE
      list(threadId = "t")
    },
    .package = "gmailr"
  )
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

test_that("a scheduled send carries inline images by name, as absolute paths", {
  # The fired job runs elsewhere (a launchd job starts in /), and the
  # Content-ID is the name, so both the path and the name must survive.
  for (sched in c("launchd", "callr")) {
    captured <- NULL
    local_mocked_bindings(
      schedule_send = function(target_time, args, scheduler) {
        captured <<- args
        list()
      },
      send_log = function(...) invisible(NULL),
      .package = "mc"
    )
    dir <- withr::local_tempdir()
    file.copy(png_file(), file.path(dir, "card.png"))
    file.copy(png_file(), file.path(dir, "map.png"))
    withr::with_dir(dir, suppressWarnings(suppressMessages(
      mc_send(html = '<img src="cid:card"><img src="cid:map">', to = "t@t.com",
              subject = "s", from = "f@f.com", sig = FALSE,
              inline_images = c(card = "card.png", map = "map.png"),
              send_at = 5, scheduler = sched)
    )))
    expect_identical(
      captured$inline_images,
      c(card = file.path(normalizePath(dir), "card.png"),
        map = file.path(normalizePath(dir), "map.png")),
      info = sched
    )
  }
})

test_that("inline images reach the fired send by name through the args JSON", {
  sent <- NULL
  local_mocked_bindings(
    mc_send = function(...) {
      sent <<- list(...)
      "tid"
    },
    send_log = function(...) invisible(NULL),
    send_notify = function(...) NULL,
    cleanup_scheduled_send = function(...) NULL,
    .package = "mc"
  )
  for (imgs in list(c(card = "/tmp/card.png"),
                    c(card = "/tmp/card.png", map = "/tmp/map.png"))) {
    path <- tempfile(fileext = ".json")
    mc:::write_scheduled_args(
      list(to = "r@x.com", subject = "s", from = "f@x.com",
           html = "<p>b</p>", inline_images = imgs),
      Sys.time(), path
    )
    mc:::run_scheduled_send(path)
    unlink(path)
    expect_identical(sent$inline_images, imgs)
  }
})

test_that("only a src attribute counts as a cid reference", {
  env <- new.env()
  capture_send(env)
  send <- function(html, imgs = NULL) {
    mc_send(html = html, to = "bob@example.com", subject = "x",
            from = "alice@example.com", sig = FALSE,
            inline_images = imgs)
  }
  # Prose that contains "cid:" is not a reference
  expect_no_error(send("<p>Placid:calm. Write cid:card to reference it.</p>"))
  # Single quotes, spaces around = and upper case are references
  img <- png_file()
  expect_no_warning(send("<img src='cid:card'>", c(card = img)))
  expect_no_warning(send('<img SRC = "cid:card">', c(card = img)))
  expect_error(send("<img src='cid:other'>", c(card = img)), "no matching inline image")
})

test_that("background, url() and unquoted src are cid references; data-src is not", {
  env <- new.env()
  capture_send(env)
  send <- function(html, imgs = NULL) {
    mc_send(html = html, to = "bob@example.com", subject = "x",
            from = "alice@example.com", sig = FALSE,
            inline_images = imgs)
  }
  for (html in c('<td background="cid:gone">', '<div style="background: url(cid:gone)">',
                 "<div style=\"background: url('cid:gone')\">", "<img src=cid:gone>")) {
    expect_error(send(html), "no inline_images", info = html)
  }
  img <- png_file()
  expect_no_warning(send('<td background="cid:card">', c(card = img)))
  expect_no_warning(send('<div style="background-image: url(cid:card)">', c(card = img)))
  # A lazy-load attribute is not what the client draws
  expect_no_error(send('<img data-src="cid:gone">'))
})

test_that("text that is not an attribute is not a cid reference", {
  env <- new.env()
  capture_send(env)
  send <- function(html) {
    mc_send(html = html, to = "bob@example.com", subject = "x",
            from = "alice@example.com", sig = FALSE)
  }
  # A code span showing the syntax, and an attribute value that mentions it
  expect_no_error(send("<p><code>src=cid:q</code> and url(cid:q) in prose</p>"))
  expect_no_error(send('<img title="src=cid:q" src="https://e.com/a.png">'))
})

test_that("a > inside another attribute does not hide a cid reference", {
  env <- new.env()
  capture_send(env)
  send <- function(html, imgs = NULL) {
    mc_send(html = html, to = "bob@example.com", subject = "x",
            from = "alice@example.com", sig = FALSE, inline_images = imgs)
  }
  expect_error(send('<img alt="flow > 5" src="cid:missing">'), "no inline_images")
  expect_no_warning(send('<img alt="a > b" src="cid:card">', c(card = png_file())))
})
