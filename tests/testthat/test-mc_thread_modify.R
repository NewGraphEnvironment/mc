test_that("mc_thread_modify rejects bad input", {
  expect_error(mc_thread_modify(thread_id = 1))
  expect_error(mc_thread_modify(thread_id = "t", add = 123))
  expect_error(mc_thread_modify(thread_id = "t", remove = TRUE))
})

test_that("mc_thread_modify errors when both add and remove are NULL", {
  expect_error(
    mc_thread_modify("t"),
    "Provide at least one of"
  )
})

test_that("mc_thread_modify passes system labels through without gm_labels call", {
  captured <- NULL
  labels_called <- FALSE
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) {
      captured <<- list(id = thread_id, add = add_ids, remove = remove_ids)
      NULL
    }
  )
  local_mocked_bindings(
    gm_labels = function(...) {
      labels_called <<- TRUE
      list(labels = list())
    },
    .package = "gmailr"
  )

  mc_thread_modify("abc123", add = "STARRED", remove = "UNREAD")

  expect_equal(captured$id, "abc123")
  expect_equal(captured$add, "STARRED")
  expect_equal(captured$remove, "UNREAD")
  expect_false(labels_called)
})

test_that("mc_thread_modify resolves user label names to IDs", {
  captured <- NULL
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) {
      captured <<- list(add = add_ids, remove = remove_ids)
      NULL
    }
  )
  local_mocked_bindings(
    gm_labels = function(...) {
      list(labels = list(
        list(id = "INBOX", name = "INBOX", type = "system"),
        list(id = "Label_7", name = "Invoiced", type = "user"),
        list(id = "Label_9", name = "Archived", type = "user")
      ))
    },
    .package = "gmailr"
  )

  mc_thread_modify("abc", add = "Invoiced", remove = "Archived")

  expect_equal(captured$add, "Label_7")
  expect_equal(captured$remove, "Label_9")
})

test_that("mc_thread_modify omits unused arg (add-only, remove-only)", {
  captured <- NULL
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) {
      captured <<- list(add = add_ids, remove = remove_ids)
      NULL
    }
  )

  mc_thread_modify("abc", add = "STARRED")
  expect_equal(captured$add, "STARRED")
  expect_null(captured$remove)

  mc_thread_modify("abc", remove = "INBOX")
  expect_null(captured$add)
  expect_equal(captured$remove, "INBOX")
})

test_that("mc_thread_modify mixes system and user labels in one call", {
  captured <- NULL
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) {
      captured <<- list(add = add_ids, remove = remove_ids)
      NULL
    }
  )
  local_mocked_bindings(
    gm_labels = function(...) {
      list(labels = list(
        list(id = "Label_7", name = "Done", type = "user"),
        list(id = "Label_8", name = "Pending", type = "user")
      ))
    },
    .package = "gmailr"
  )

  mc_thread_modify(
    "abc",
    add = c("Done", "STARRED"),
    remove = c("Pending", "UNREAD")
  )

  expect_equal(captured$add, c("Label_7", "STARRED"))
  expect_equal(captured$remove, c("Label_8", "UNREAD"))
})

test_that("mc_thread_modify errors on unknown label with available hint", {
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) NULL
  )
  local_mocked_bindings(
    gm_labels = function(...) {
      list(labels = list(
        list(id = "Label_1", name = "Invoiced", type = "user"),
        list(id = "Label_2", name = "Clients/Acme", type = "user")
      ))
    },
    .package = "gmailr"
  )

  expect_error(
    mc_thread_modify("abc", add = "Nonexistent"),
    'Label\\(s\\) not found: "Nonexistent"'
  )
  expect_error(
    mc_thread_modify("abc", add = "Nonexistent"),
    "Invoiced"
  )
})

test_that("mc_thread_modify error shows (none) when user has no labels", {
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) NULL
  )
  local_mocked_bindings(
    gm_labels = function(...) list(labels = list()),
    .package = "gmailr"
  )

  expect_error(
    mc_thread_modify("abc", add = "Whatever"),
    "Available user labels: \\(none\\)"
  )
})

test_that("system label wins when user label name collides", {
  captured <- NULL
  local_mocked_bindings(
    gmail_modify_thread = function(thread_id, add_ids, remove_ids) {
      captured <<- list(add = add_ids, remove = remove_ids)
      NULL
    }
  )
  local_mocked_bindings(
    gm_labels = function(...) {
      # User has (pathologically) created a label named "STARRED"
      list(labels = list(
        list(id = "Label_99", name = "STARRED", type = "user")
      ))
    },
    .package = "gmailr"
  )

  mc_thread_modify("abc", add = "STARRED")
  # System interpretation wins — passes "STARRED", not "Label_99"
  expect_equal(captured$add, "STARRED")
})

test_that("resolve_label_names returns NULL for NULL input", {
  expect_null(mc:::resolve_label_names(NULL, NULL))
  expect_null(mc:::resolve_label_names(NULL, c(foo = "Label_1")))
})

test_that("system_labels returns expected IDs", {
  sys <- mc:::system_labels()
  expect_true(all(c("INBOX", "STARRED", "UNREAD", "TRASH", "SPAM") %in% sys))
})
