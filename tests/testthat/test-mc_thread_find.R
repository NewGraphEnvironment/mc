test_that("mc_thread_find rejects bad input", {
  expect_error(mc_thread_find(query = 1))
  expect_error(mc_thread_find(query = "x", n = "five"))
})

test_that("add_date_filters appends Gmail operators", {
  expect_equal(
    mc:::add_date_filters("q", as.Date("2026-04-13"), NULL),
    "q after:2026/04/13"
  )
  expect_equal(
    mc:::add_date_filters("q", "2026-04-13", "2026-04-20"),
    "q after:2026/04/13 before:2026/04/20"
  )
  expect_equal(mc:::add_date_filters("q", NULL, NULL), "q")
})

test_that("add_date_filters errors on bad strings", {
  expect_error(mc:::add_date_filters("q", "not-a-date", NULL))
})

test_that("mc_thread_find forwards date-augmented query to gmailr", {
  captured <- NULL
  fake_messages <- function(search, num_results) {
    captured <<- search
    list()
  }
  mockery::stub(mc_thread_find, "gmailr::gm_messages", fake_messages)
  mockery::stub(mc_thread_find, "gmailr::gm_id", function(x) character(0))
  suppressMessages(mc_thread_find("newsletter", after = "2026-04-13"))
  expect_equal(captured, "newsletter after:2026/04/13")
})
