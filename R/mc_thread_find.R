#' Search Gmail for thread IDs
#'
#' Searches Gmail messages and returns matching thread IDs. Useful for
#' finding the `thread_id` to pass to [mc_send()] when replying into
#' an existing conversation.
#'
#' @param query Gmail search query. Supports the same syntax as the Gmail
#'   search box (e.g., `"from:brandon subject:cottonwood"`).
#' @param n Maximum number of results. Default `5`.
#'
#' @return A data frame with columns `thread_id`, `from`, `subject`, and
#'   `date`, sorted by most recent first.
#'
#' @examples
#' \dontrun{
#' mc_thread_find("from:brandon.geldart subject:cottonwood")
#' mc_thread_find("from:brandon newer_than:7d")
#' }
#'
#' @export
mc_thread_find <- function(query, n = 5) {
  chk::chk_string(query)
  chk::chk_whole_number(n)
  results <- gmailr::gm_messages(search = query, num_results = n)
  ids <- gmailr::gm_id(results)

  if (length(ids) == 0) {
    message("No messages found for query: ", query)
    return(data.frame(
      thread_id = character(0),
      from = character(0),
      subject = character(0),
      date = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(ids, function(msg_id) {
    msg <- gmailr::gm_message(msg_id)
    data.frame(
      thread_id = gmailr::gm_thread_id(msg) %||% NA_character_,
      from = extract_header(msg, "From"),
      subject = extract_header(msg, "Subject"),
      date = extract_header(msg, "Date"),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}


#' Null/empty coalescing operator
#'
#' Like base `%||%` but also catches `length(x) == 0`.
#' Base R added `%||%` in 4.4.0; this version is safe on R >= 4.1
#' because user-defined infix operators mask the base version within
#' the package namespace without a NOTE.
#' @noRd
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x


#' Extract a header value from a gmailr message
#' @param msg A gmailr message object.
#' @param name Header name (e.g., "From", "Subject", "Date").
#' @return Character string or `NA_character_`.
#' @noRd
extract_header <- function(msg, name) {
  headers <- msg$payload$headers
  if (is.null(headers)) return(NA_character_)
  for (h in headers) {
    if (identical(h$name, name)) return(h$value)
  }
  NA_character_
}
