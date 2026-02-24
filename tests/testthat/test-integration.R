# Integration tests — require live Gmail auth
# Run locally with devtools::test(), skipped in CI

skip_if_not(
  tryCatch({
    gmailr::gm_auth(email = "al@newgraphenvironment.com")
    TRUE
  }, error = function(e) FALSE),
  "Gmail auth not available"
)

test_tag <- format(Sys.time(), "mc-test-%Y%m%d-%H%M%S")
env <- new.env(parent = emptyenv())

test_that("mc_send creates a draft", {
  mc_send(
    html = paste0("<p>Integration test: ", test_tag, "</p>"),
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
    html = paste0("<p>Sent test: ", test_tag, "</p>"),
    to = "al@newgraphenvironment.com",
    subject = paste("Sent", test_tag),
    draft = FALSE,
    test = TRUE,
    sig = FALSE
  )

  Sys.sleep(5)

  results <- gmailr::gm_messages(
    search = paste0("subject:\"Sent ", test_tag, "\" in:sent"),
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
  results <- mc_thread_find(paste("subject:\"Sent", test_tag, "\""))
  expect_true(nrow(results) > 0, info = "Thread not found by mc_thread_find")
  expect_true(thread_id %in% results$thread_id)
})

test_that("mc_thread_read returns the test message", {
  thread_id <- env$test_thread_id
  thread <- mc_thread_read(thread_id)
  expect_true(nrow(thread) > 0, info = "No messages in thread")
  expect_true(any(grepl(test_tag, thread$subject)))
})

test_that("mc_send replies into the test thread", {
  thread_id <- env$test_thread_id

  # Can't use test = TRUE here — it strips thread_id
  mc_send(
    html = paste0("<p>Reply test: ", test_tag, "</p>"),
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

test_that("mc_compose with mc_scroll sends a table email", {
  df <- data.frame(
    Site = c("Nechako", "Mackenzie", "Skeena"),
    Plugs = c(4000, 3000, 3000)
  )

  body <- mc_compose(
    paste0("<p>Table test: ", test_tag, "</p>"),
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
    search = paste0("subject:\"Table ", test_tag, "\""),
    num_results = 1
  )
  ids <- gmailr::gm_id(results)
  expect_true(length(ids) > 0, info = "Table email not found")
})
