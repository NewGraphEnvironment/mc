test_that("mc_label_ensure rejects non-character", {
  expect_error(mc_label_ensure(42), "label_names")
  expect_error(mc_label_ensure(NULL), "label_names")
})

test_that("mc_label_ensure no-ops when all labels exist", {
  created <- character(0)
  local_mocked_bindings(
    gm_labels = function() {
      list(
        labels = list(
          list(id = "Label_1", name = "foo", type = "user"),
          list(id = "Label_2", name = "bar", type = "user")
        )
      )
    },
    gm_create_label = function(name, ...) {
      created <<- c(created, name)
      list()
    },
    .package = "gmailr"
  )
  res <- mc_label_ensure(c("foo", "bar"))
  expect_equal(created, character(0))
  expect_equal(res, c("foo", "bar"))
})

test_that("mc_label_ensure creates only missing names", {
  created <- character(0)
  local_mocked_bindings(
    gm_labels = function() {
      list(
        labels = list(
          list(id = "Label_1", name = "foo", type = "user")
        )
      )
    },
    gm_create_label = function(name, ...) {
      created <<- c(created, name)
      list()
    },
    .package = "gmailr"
  )
  mc_label_ensure(c("foo", "new-one", "another-new"))
  expect_equal(created, c("new-one", "another-new"))
})

test_that("mc_label_ensure skips system labels (case-insensitive)", {
  created <- character(0)
  local_mocked_bindings(
    gm_labels = function() list(labels = list()),
    gm_create_label = function(name, ...) {
      created <<- c(created, name)
      list()
    },
    .package = "gmailr"
  )
  mc_label_ensure(c("STARRED", "Inbox", "inbox", "real-label"))
  expect_equal(created, "real-label")
})

test_that("mc_label_ensure returns invisibly", {
  local_mocked_bindings(
    gm_labels = function() list(labels = list()),
    gm_create_label = function(name, ...) list(),
    .package = "gmailr"
  )
  expect_invisible(mc_label_ensure("x"))
})

test_that("mc_label_ensure no-ops on empty input without fetching labels", {
  local_mocked_bindings(
    gm_labels = function() stop("should not be called"),
    .package = "gmailr"
  )
  res <- mc_label_ensure(character(0))
  expect_equal(res, character(0))
})
