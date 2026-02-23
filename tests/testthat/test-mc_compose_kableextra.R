test_that("mc_compose handles kableExtra styled tables", {
  skip_if_not_installed("kableExtra")

  df <- data.frame(Site = c("Nechako", "Mackenzie"), Plugs = c(4000, 3000))

  tbl <- kableExtra::kbl(df, format = "html") |>
    kableExtra::kable_styling(full_width = FALSE) |>
    kableExtra::row_spec(0, bold = TRUE, background = "#f5f5f5") |>
    kableExtra::column_spec(2, bold = TRUE, color = "#2c7bb6")

  body <- mc_compose("<p>Summary:</p>", tbl, sig = FALSE)

  # Table present with data
  expect_match(body, "Nechako")
  expect_match(body, "4000")

  # Border styles injected
  expect_match(body, "border: 1px solid #ddd")

  # kableExtra inline styles preserved
  expect_match(body, "font-weight: bold")
})
