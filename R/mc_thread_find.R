#' Search Gmail for thread IDs
#'
#' Searches Gmail messages and returns matching thread IDs. Useful for
#' finding the `thread_id` to pass to [mc_send()] when replying into
#' an existing conversation.
#'
#' @param query Gmail search query. Supports the same syntax as the Gmail
#'   search box (e.g., `"from:brandon subject:cottonwood"`).
#' @param n Maximum number of results. Default `5`.
#' @param after,before Optional date filters. `Date` object or character
#'   string in `"YYYY-MM-DD"` form. Translated to Gmail's `after:` / `before:`
#'   operators (inclusive/exclusive semantics follow Gmail's behaviour:
#'   `after:` is inclusive, `before:` is exclusive).
#'
#' @return A data frame with columns `thread_id`, `from`, `subject`, and
#'   `date`, sorted by most recent first.
#'
#' @examples
#' \dontrun{
#' mc_thread_find("from:brandon.geldart subject:cottonwood")
#' mc_thread_find("from:brandon newer_than:7d")
#' mc_thread_find("newsletter", after = Sys.Date() - 7)
#' }
#'
#' @importFrom chk chk_string chk_whole_number
#' @importFrom gmailr gm_messages gm_id gm_message
#' @export
mc_thread_find <- function(query, n = 5, after = NULL, before = NULL) {
  chk::chk_string(query)
  chk::chk_whole_number(n)
  query <- add_date_filters(query, after, before)
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
#' @param drafts Logical. If `TRUE`, also include draft messages in the
#'   output and add a `status` column (`"sent"` or `"draft"`).
#'   Default `FALSE` for backwards compatibility.
#'
#' @return A data frame with columns `from`, `date`, `subject`, and `body`,
#'   ordered oldest to newest. When `drafts = TRUE`, an additional `status`
#'   column is included.
#'
#' @examples
#' \dontrun{
#' mc_thread_find("from:brandon subject:cottonwood")
#' mc_thread_read("19adb18351867c34")
#' mc_thread_read("19adb18351867c34", drafts = TRUE)
#' }
#'
#' @importFrom chk chk_string chk_flag
#' @importFrom gmailr gm_thread gm_drafts gm_draft
#' @importFrom jsonlite base64url_dec
#' @export
mc_thread_read <- function(thread_id, drafts = FALSE) {
  chk::chk_string(thread_id)
  chk::chk_flag(drafts)

  thread <- gmailr::gm_thread(id = thread_id)
  msgs <- thread$messages

  empty <- data.frame(
    from = character(0),
    date = character(0),
    subject = character(0),
    body = character(0),
    stringsAsFactors = FALSE
  )
  if (drafts) empty$status <- character(0)

  if (is.null(msgs) || length(msgs) == 0) {
    if (!drafts) {
      message("No messages in thread: ", thread_id)
      return(empty)
    }
  }

  rows <- lapply(msgs %||% list(), function(msg) {
    body <- extract_body(msg$payload, "text/plain")
    if (!nzchar(body)) {
      body_html <- extract_body(msg$payload, "text/html")
      if (nzchar(body_html)) {
        body <- gsub("<[^>]+>", " ", body_html)
        body <- gsub("[ \t]+", " ", body)
        body <- trimws(body)
      }
    }
    row <- data.frame(
      from = extract_header(msg, "From"),
      date = extract_header(msg, "Date"),
      subject = extract_header(msg, "Subject"),
      body = body,
      stringsAsFactors = FALSE
    )
    if (drafts) row$status <- "sent"
    row
  })

  if (drafts) {
    draft_rows <- fetch_thread_drafts(thread_id)
    rows <- c(rows, draft_rows)
  }

  result <- do.call(rbind, rows)

  if (is.null(result) || nrow(result) == 0) {
    message("No messages in thread: ", thread_id)
    return(empty)
  }

  result
}


#' Return the latest top-level message body in a thread
#'
#' Convenience wrapper over [mc_thread_read()] that pulls the most recent
#' message in a thread and, by default, strips quoted reply history so you
#' get just what was actually written at the top. Useful for recording what
#' was sent, comparing draft vs sent, or scanning thread activity.
#'
#' @param thread_id Gmail thread ID.
#' @param strip_quotes Logical. If `TRUE` (default), remove lines starting
#'   with `>` plus the `"On ... wrote:"` attribution line that Gmail inserts
#'   above quoted history.
#' @param status One of `"any"` (default), `"sent"`, or `"draft"`. Restricts
#'   the pool of messages considered when selecting the latest.
#'
#' @return A single character string with the latest body (or `""` if none).
#'
#' @examples
#' \dontrun{
#' mc_thread_body_latest("19cd3565c3161b4b")
#' mc_thread_body_latest("19cd3565c3161b4b", strip_quotes = FALSE)
#' }
#'
#' @importFrom chk chk_string chk_flag
#' @export
mc_thread_body_latest <- function(thread_id, strip_quotes = TRUE,
                                  status = c("any", "sent", "draft")) {
  chk::chk_string(thread_id)
  chk::chk_flag(strip_quotes)
  status <- match.arg(status)

  df <- suppressMessages(mc_thread_read(thread_id, drafts = TRUE))
  if (nrow(df) == 0) return("")

  if (status != "any") df <- df[df$status == status, , drop = FALSE]
  if (nrow(df) == 0) return("")

  body <- df$body[nrow(df)]
  if (strip_quotes) body <- strip_quoted(body)
  body
}


#' Strip quoted reply history from a plain-text email body
#'
#' Removes the "On ... wrote:" attribution line and the trailing block of
#' `^>` quoted lines that Gmail (and most clients) emit.
#' @param text Character string.
#' @return Character string with quoted history removed and trailing whitespace trimmed.
#' @noRd
strip_quoted <- function(text) {
  if (is.na(text) || !nzchar(text)) return(text)
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  keep <- !grepl("^>", lines)
  lines <- lines[keep]
  # Drop trailing "On ... wrote:" attribution (possibly split across lines
  # ending with ':' on the last kept line).
  while (length(lines) > 0) {
    last <- lines[length(lines)]
    if (grepl("^On .* wrote:$", trimws(last)) ||
          grepl("wrote:$", trimws(last)) && grepl("^On ", trimws(last))) {
      lines <- lines[-length(lines)]
    } else {
      break
    }
  }
  trimws(paste(lines, collapse = "\n"))
}


#' Fetch draft messages belonging to a specific thread
#'
#' Scans Gmail drafts and returns rows for any that belong to the given
#' thread. Used internally by [mc_thread_read()] when `drafts = TRUE`.
#' @param thread_id Gmail thread ID.
#' @return List of data frame rows (may be empty).
#' @noRd
fetch_thread_drafts <- function(thread_id) {
  all_drafts <- gmailr::gm_drafts(num_results = 50)
  draft_list <- all_drafts[[1]]$drafts
  if (is.null(draft_list) || length(draft_list) == 0) return(list())

  rows <- list()
  for (d in draft_list) {
    detail <- gmailr::gm_draft(d$id)
    msg <- detail$message
    if (!identical(msg$threadId, thread_id)) next

    body <- extract_body(msg$payload, "text/plain")
    if (!nzchar(body)) {
      body_html <- extract_body(msg$payload, "text/html")
      if (nzchar(body_html)) {
        body <- gsub("<[^>]+>", " ", body_html)
        body <- gsub("[ \t]+", " ", body)
        body <- trimws(body)
      }
    }
    rows[[length(rows) + 1]] <- data.frame(
      from = extract_header(msg, "From"),
      date = extract_header(msg, "Date"),
      subject = extract_header(msg, "Subject"),
      body = body,
      status = "draft",
      stringsAsFactors = FALSE
    )
  }
  rows
}


#' Translate `after`/`before` Date or character args into Gmail operators
#'
#' Appends `after:YYYY/MM/DD` / `before:YYYY/MM/DD` to a search query. Each
#' input may be `NULL` (no filter), a `Date`, or a character string parseable
#' as a date.
#' @param query Existing Gmail search query string.
#' @param after,before `Date`, character, or `NULL`.
#' @return Query string with date operators appended.
#' @noRd
add_date_filters <- function(query, after, before) {
  fmt <- function(x, label) {
    if (is.null(x)) return(NULL)
    if (inherits(x, "Date")) return(format(x, "%Y/%m/%d"))
    chk::chk_string(x, x_name = label)
    d <- tryCatch(as.Date(x), error = function(e) NA)
    if (is.na(d)) stop("`", label, "` must be a Date or YYYY-MM-DD string")
    format(d, "%Y/%m/%d")
  }
  a <- fmt(after, "after")
  b <- fmt(before, "before")
  parts <- c(query, if (!is.null(a)) paste0("after:", a),
             if (!is.null(b)) paste0("before:", b))
  paste(parts, collapse = " ")
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
