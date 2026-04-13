test_that("mc_md_index rejects bad input", {
  expect_error(mc_md_index(dir = 1))
  expect_error(mc_md_index(dir = ".", pattern = 1))
  expect_error(mc_md_index(dir = ".", recursive = "y"))
})

test_that("mc_md_index returns empty df for dir with no drafts", {
  d <- tempfile(); dir.create(d)
  out <- mc_md_index(d)
  expect_equal(nrow(out), 0)
  expect_equal(names(out), c("path", "date", "to", "cc", "subject",
                              "thread_id", "has_attachments"))
})

test_that("mc_md_index scans and parses frontmatter", {
  d <- tempfile(); dir.create(d)
  f1 <- file.path(d, "20260413_cindy_newsletter_draft.md")
  writeLines(c(
    "---",
    "to: cindy@x.com",
    "cc: [a@x.com, b@x.com]",
    "subject: Newsletter",
    "thread_id: t1",
    "attachments: [/tmp/a.pdf]",
    "---",
    "body"
  ), f1)
  f2 <- file.path(d, "no_frontmatter_draft.md")
  writeLines("body only", f2)

  out <- mc_md_index(d)
  expect_equal(nrow(out), 2)

  row1 <- out[basename(out$path) == basename(f1), ]
  expect_equal(row1$to, "cindy@x.com")
  expect_equal(row1$cc, "a@x.com, b@x.com")
  expect_equal(row1$subject, "Newsletter")
  expect_equal(row1$thread_id, "t1")
  expect_true(row1$has_attachments)
  expect_equal(row1$date, as.Date("2026-04-13"))

  row2 <- out[basename(out$path) == basename(f2), ]
  expect_true(is.na(row2$to))
  expect_false(row2$has_attachments)
  expect_true(is.na(row2$date))
})

test_that("mc_md_index respects recursive = FALSE", {
  d <- tempfile(); dir.create(d)
  sub <- file.path(d, "sub"); dir.create(sub)
  writeLines("---\nto: a@x.com\nsubject: hi\n---\nbody",
             file.path(sub, "20260101_x_draft.md"))
  expect_equal(nrow(mc_md_index(d, recursive = FALSE)), 0)
  expect_equal(nrow(mc_md_index(d, recursive = TRUE)), 1)
})
