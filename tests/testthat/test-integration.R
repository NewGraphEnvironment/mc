# Integration tests — require live Gmail auth + explicit opt-in
# Run with: MC_RUN_INTEGRATION=true devtools::test(filter = "integration")
# Test emails are trashed automatically after the run.

skip_if_not(
  identical(Sys.getenv("MC_RUN_INTEGRATION"), "true"),
  "Set MC_RUN_INTEGRATION=true to run integration tests"
)

skip_if_not(
  tryCatch({
    gmailr::gm_auth(email = "al@newgraphenvironment.com")
    TRUE
  }, error = function(e) FALSE),
  "Gmail auth not available"
)

# Simple searchable tag (no special chars — Gmail search chokes on brackets/pipes)
test_tag <- format(Sys.time(), "mc-test-%Y%m%d-%H%M%S")

# Metadata for email body — human-readable traceability
test_meta <- sprintf(
  "mc %s | R %s | %s | %s",
  as.character(utils::packageVersion("mc")),
  paste(R.version$major, R.version$minor, sep = "."),
  R.version$os,
  format(Sys.time(), "%Y-%m-%d %H:%M:%S")
)

env <- new.env(parent = emptyenv())

# Trash test messages after the run.
# Safeguards against trashing unrelated mail:
#   1. newer_than:1h — only messages from the last hour
#   2. Subject verified — each message's subject must contain the exact test_tag
#      (Gmail search is fuzzy/tokenized; this confirms the match)
#   3. test_tag includes timestamp to the second — collisions near-impossible
withr::defer({
  Sys.sleep(5)
  for (label in c("", " in:sent", " in:drafts", " in:inbox")) {
    results <- gmailr::gm_messages(
      search = paste0("subject:", test_tag, " newer_than:1h", label),
      num_results = 20
    )
    for (id in gmailr::gm_id(results)) {
      tryCatch({
        msg <- gmailr::gm_message(id)
        subj <- msg$payload$headers |>
          vapply(\(h) if (h$name == "Subject") h$value else NA_character_, character(1))
        subj <- subj[!is.na(subj)][1]
        if (!is.na(subj) && grepl(test_tag, subj, fixed = TRUE)) {
          gmailr::gm_trash_message(id)
        }
      }, error = function(e) NULL)
    }
  }
}, envir = parent.frame())

test_that("mc_send creates a draft", {
  mc_send(
    html = paste0("<p>Integration test: ", test_tag, "</p><pre>", test_meta, "</pre>"),
    to = "al@newgraphenvironment.com",
    subject = test_tag,
    sig = FALSE
  )

  # Give Gmail a moment to index
  Sys.sleep(3)

  # Search for the draft by subject
  results <- gmailr::gm_messages(
    search = paste0("subject:", test_tag, " in:drafts"),
    num_results = 1
  )
  ids <- gmailr::gm_id(results)
  expect_true(length(ids) > 0, info = "Draft not found in Gmail")
})

test_that("mc_send sends to self", {
  mc_send(
    html = paste0("<p>Sent test: ", test_tag, "</p><pre>", test_meta, "</pre>"),
    to = "al@newgraphenvironment.com",
    subject = paste("Sent", test_tag),
    draft = FALSE,
    test = TRUE,
    sig = FALSE
  )

  Sys.sleep(5)

  results <- gmailr::gm_messages(
    search = paste0("subject:", test_tag, " in:sent"),
    num_results = 1
  )
  ids <- gmailr::gm_id(results)
  expect_true(length(ids) > 0, info = "Sent message not found in Gmail")

  # Store thread_id for threading tests
  msg <- gmailr::gm_message(ids[[1]])
  env$test_thread_id <- msg$threadId
})

test_that("mc_thread_find locates the test thread", {
  thread_id <- env$test_thread_id
  results <- mc_thread_find(paste0("subject:", test_tag))
  expect_true(nrow(results) > 0, info = "Thread not found by mc_thread_find")
  expect_true(thread_id %in% results$thread_id)
})

test_that("mc_thread_read returns the test message", {
  thread_id <- env$test_thread_id
  thread <- mc_thread_read(thread_id)
  expect_true(nrow(thread) > 0, info = "No messages in thread")
  expect_true(any(grepl(test_tag, thread$subject, fixed = TRUE)))
})

test_that("mc_send replies into the test thread", {
  thread_id <- env$test_thread_id

  # Can't use test = TRUE here — it strips thread_id
  mc_send(
    html = paste0("<p>Reply test: ", test_tag, "</p><pre>", test_meta, "</pre>"),
    to = "al@newgraphenvironment.com",
    subject = paste("Re: Sent", test_tag),
    thread_id = thread_id,
    draft = FALSE,
    sig = FALSE
  )

  # Gmail needs time to index the reply into the thread
  Sys.sleep(10)

  # Verify the thread now has 2 messages
  thread <- mc_thread_read(thread_id)
  expect_true(
    nrow(thread) >= 2,
    info = paste("Expected 2+ messages in thread, got", nrow(thread))
  )
})

test_that("mc_thread_modify adds and removes a user label", {
  thread_id <- env$test_thread_id
  skip_if(is.null(thread_id), "Test thread not available")

  label_name <- paste0("mc-label-", format(Sys.time(), "%Y%m%d-%H%M%S"))
  created <- gmailr::gm_create_label(label_name)
  label_id <- created$id
  withr::defer(
    tryCatch(gmailr::gm_delete_label(label_id), error = function(e) NULL)
  )

  # Apply the user label
  mc_thread_modify(thread_id, add = label_name)
  Sys.sleep(3)

  thread <- gmailr::gm_thread(id = thread_id)
  msg_labels <- unlist(lapply(thread$messages, function(m) m$labelIds))
  expect_true(
    label_id %in% msg_labels,
    info = "Label not found on thread after mc_thread_modify(add = ...)"
  )

  # Remove it
  mc_thread_modify(thread_id, remove = label_name)
  Sys.sleep(3)

  thread <- gmailr::gm_thread(id = thread_id)
  msg_labels <- unlist(lapply(thread$messages, function(m) m$labelIds))
  expect_false(
    label_id %in% msg_labels,
    info = "Label still present after mc_thread_modify(remove = ...)"
  )
})

test_that("mc_thread_modify passes system labels through (star/unstar)", {
  thread_id <- env$test_thread_id
  skip_if(is.null(thread_id), "Test thread not available")

  mc_thread_modify(thread_id, add = "STARRED")
  Sys.sleep(3)
  thread <- gmailr::gm_thread(id = thread_id)
  msg_labels <- unlist(lapply(thread$messages, function(m) m$labelIds))
  expect_true("STARRED" %in% msg_labels)

  mc_thread_modify(thread_id, remove = "STARRED")
  Sys.sleep(3)
  thread <- gmailr::gm_thread(id = thread_id)
  msg_labels <- unlist(lapply(thread$messages, function(m) m$labelIds))
  expect_false("STARRED" %in% msg_labels)
})

test_that("mc_compose with mc_scroll sends a table email", {
  df <- data.frame(
    Site = c("Nechako", "Mackenzie", "Skeena"),
    Plugs = c(4000, 3000, 3000)
  )

  body <- mc_compose(
    paste0("<p>Table test: ", test_tag, "</p><pre>", test_meta, "</pre>"),
    mc_scroll(knitr::kable(df, format = "html"), direction = "both"),
    sig = FALSE
  )

  mc_send(
    html = body,
    to = "al@newgraphenvironment.com",
    subject = paste("Table", test_tag),
    draft = FALSE,
    test = TRUE,
    sig = FALSE
  )

  Sys.sleep(5)

  results <- gmailr::gm_messages(
    search = paste0("subject:", test_tag),
    num_results = 1
  )
  ids <- gmailr::gm_id(results)
  expect_true(length(ids) > 0, info = "Table email not found")
})
