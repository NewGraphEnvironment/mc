#' Search Gmail at the message level
#'
#' Like [mc_thread_find()] but returns one row per message rather than per
#' thread. Useful when timed sends, re-threads, or manually moved drafts
#' scatter a logical conversation across multiple thread IDs and you want
#' to locate a specific message directly.
#'
#' @param query Gmail search query.
#' @param n Maximum number of results. Default `10`.
#' @param after,before Optional date filters. `Date` or `"YYYY-MM-DD"`
#'   string. See [mc_thread_find()].
#' @param status One of `"any"` (default), `"sent"`, or `"draft"`. `"sent"`
#'   restricts to non-draft messages; `"draft"` searches drafts instead of
#'   messages.
#'
#' @return A data frame with columns `message_id`, `thread_id`, `from`, `to`,
#'   `subject`, `date`, and `status`, most recent first. Returns an empty
#'   data frame (same columns) when no messages match.
#'
#' @examples
#' \dontrun{
#' mc_message_find("to:cindy newsletter", after = Sys.Date() - 1)
#' mc_message_find("subject:invoice", status = "sent")
#' mc_message_find("subject:draft-only", status = "draft")
#' }
#'
#' @importFrom chk chk_string chk_whole_number
#' @importFrom gmailr gm_messages gm_id gm_message gm_drafts gm_draft
#' @export
mc_message_find <- function(query, n = 10, after = NULL, before = NULL,
                            status = c("any", "sent", "draft")) {
  chk::chk_string(query)
  chk::chk_whole_number(n)
  status <- match.arg(status)
  query <- add_date_filters(query, after, before)

  empty <- data.frame(
    message_id = character(0),
    thread_id = character(0),
    from = character(0),
    to = character(0),
    subject = character(0),
    date = character(0),
    status = character(0),
    stringsAsFactors = FALSE
  )

  rows <- list()

  if (status %in% c("any", "sent")) {
    q <- if (status == "sent") paste(query, "-in:drafts") else query
    results <- gmailr::gm_messages(search = q, num_results = n)
    ids <- gmailr::gm_id(results)
    for (id in ids) {
      msg <- gmailr::gm_message(id)
      rows[[length(rows) + 1]] <- message_row(msg, status = "sent")
    }
  }

  if (status %in% c("any", "draft")) {
    all_drafts <- gmailr::gm_drafts(num_results = n)
    draft_list <- all_drafts[[1]]$drafts
    for (d in draft_list %||% list()) {
      detail <- gmailr::gm_draft(d$id)
      msg <- detail$message
      rows[[length(rows) + 1]] <- message_row(msg, status = "draft")
    }
  }

  if (length(rows) == 0) {
    message("No messages found for query: ", query)
    return(empty)
  }

  result <- do.call(rbind, rows)
  result[order(result$date, decreasing = TRUE), , drop = FALSE]
}


#' Build a one-row message data frame from a gmailr message object
#' @noRd
message_row <- function(msg, status) {
  data.frame(
    message_id = msg$id %||% NA_character_,
    thread_id = msg$threadId %||% NA_character_,
    from = extract_header(msg, "From"),
    to = extract_header(msg, "To"),
    subject = extract_header(msg, "Subject"),
    date = extract_header(msg, "Date"),
    status = status,
    stringsAsFactors = FALSE
  )
}
