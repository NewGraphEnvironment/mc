test_that("mc_scroll wraps HTML string with both direction", {
  html <- mc_scroll("<table><tr><td>x</td></tr></table>")
  expect_match(html, "overflow: auto")
  expect_match(html, "max-height: 400px")
  expect_match(html, "max-width: 100%")
  expect_match(html, "<table")
})

test_that("mc_scroll wide direction uses overflow-x", {
  html <- mc_scroll("<table></table>", direction = "wide")
  expect_match(html, "overflow-x: auto")
  expect_false(grepl("max-height", html))
})

test_that("mc_scroll long direction uses overflow-y", {
  html <- mc_scroll("<table></table>", direction = "long")
  expect_match(html, "overflow-y: auto")
  expect_match(html, "max-height: 400px")
})

test_that("mc_scroll custom max_height", {
  html <- mc_scroll("<table></table>", direction = "long", max_height = "600px")
  expect_match(html, "max-height: 600px")
})

test_that("mc_scroll handles kable objects", {
  df <- data.frame(X = 1:3)
  tbl <- knitr::kable(df, format = "html")
  html <- mc_scroll(tbl, direction = "wide")
  expect_match(html, "overflow-x: auto")
  expect_match(html, "<table")
})

test_that("mc_scroll rejects bad direction", {
  expect_error(mc_scroll("<table></table>", direction = "diagonal"))
})

test_that("mc_scroll rejects bad types", {
  expect_error(mc_scroll(123))
  expect_error(mc_scroll("<table></table>", direction = 1))
})

test_that("mc_scroll works inside mc_compose", {
  df <- data.frame(X = 1:3, Y = 4:6)
  tbl <- knitr::kable(df, format = "html")

  body <- mc_compose(
    "<p>Before</p>",
    mc_scroll(tbl, direction = "wide"),
    "<p>After</p>",
    sig = FALSE
  )
  expect_match(body, "overflow-x: auto")
  expect_match(body, "Before")
  expect_match(body, "After")
  expect_match(body, "border: 1px solid #ddd")
})
