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
#' @importFrom chk chk_string chk_whole_number
#' @importFrom gmailr gm_messages gm_id gm_message
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
      thread_id = msg$threadId %||% NA_character_,
      from = extract_header(msg, "From"),
      subject = extract_header(msg, "Subject"),
      date = extract_header(msg, "Date"),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}


#' Read all messages in a Gmail thread
#'
#' Fetches a thread by ID and returns each message's sender, date, subject,
#' and plain-text body. Useful for reviewing a conversation before composing
#' a follow-up with [mc_send()].
#'
#' @param thread_id Gmail thread ID (from [mc_thread_find()]).
#'
#' @return A data frame with columns `from`, `date`, `subject`, and `body`,
#'   ordered oldest to newest.
#'
#' @examples
#' \dontrun{
#' mc_thread_find("from:brandon subject:cottonwood")
#' mc_thread_read("19adb18351867c34")
#' }
#'
#' @importFrom chk chk_string
#' @importFrom gmailr gm_thread
#' @importFrom jsonlite base64url_dec
#' @export
mc_thread_read <- function(thread_id) {
  chk::chk_string(thread_id)

  thread <- gmailr::gm_thread(id = thread_id)
  msgs <- thread$messages

  if (is.null(msgs) || length(msgs) == 0) {
    message("No messages in thread: ", thread_id)
    return(data.frame(
      from = character(0),
      date = character(0),
      subject = character(0),
      body = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(msgs, function(msg) {
    body <- extract_body(msg$payload, "text/plain")
    if (!nzchar(body)) {
      body_html <- extract_body(msg$payload, "text/html")
      if (nzchar(body_html)) {
        body <- gsub("<[^>]+>", " ", body_html)
        body <- gsub("[ \t]+", " ", body)
        body <- trimws(body)
      }
    }
    data.frame(
      from = extract_header(msg, "From"),
      date = extract_header(msg, "Date"),
      subject = extract_header(msg, "Subject"),
      body = body,
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


#' Extract body text from a MIME payload, recursing into nested parts
#'
#' Gmail wraps replies in nested multipart structures that `gm_body()`
#' can miss. This walks the tree to find the first part matching `mime_type`.
#' @param payload A message payload (list with `mimeType`, `body`, `parts`).
#' @param mime_type MIME type to extract (e.g., `"text/plain"`).
#' @return Character string (decoded body) or `""` if not found.
#' @noRd
extract_body <- function(payload, mime_type) {
  if (is.null(payload)) return("")
  # Leaf node with matching type

  if (identical(payload$mimeType, mime_type) &&
        !is.null(payload$body$data) && payload$body$size > 0) {
    return(rawToChar(jsonlite::base64url_dec(payload$body$data)))
  }
  # Recurse into parts
  for (part in payload$parts) {
    result <- extract_body(part, mime_type)
    if (nzchar(result)) return(result)
  }
  ""
}


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
