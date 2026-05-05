#' Modify a Gmail thread's label state (archive, trash, star, label, etc.)
#'
#' Adds and/or removes labels on a thread in one call. Accepts user-defined
#' label names or Gmail system labels (INBOX, STARRED, UNREAD, IMPORTANT,
#' TRASH, SPAM, SENT, DRAFT). Covers common operations beyond "labeling":
#' archive (`remove = "INBOX"`), star (`add = "STARRED"`), trash
#' (`add = "TRASH"`), mark-read (`remove = "UNREAD"`).
#'
#' @param thread_id Gmail thread ID (e.g. from [mc_thread_find()]).
#' @param add Character vector of label names to add. `NULL` for none.
#' @param remove Character vector of label names to remove. `NULL` for none.
#' @param create_missing Logical. When `TRUE`, calls [mc_label_ensure()] on
#'   `add` before resolving names — any user label in `add` that doesn't yet
#'   exist is created. Defaults `FALSE` (strict: errors on unknown labels)
#'   so existing callers keep their typo guard.
#'
#' @details
#' Pass **names**, not IDs. User-label names resolve to opaque IDs via
#' [gmailr::gm_labels()]. System labels pass through unchanged. When a user
#' label's name collides with a system label ID (e.g. a user label named
#' `"STARRED"`), the system interpretation wins — almost always what's
#' intended.
#'
#' At least one of `add` or `remove` must be non-`NULL`. The `gm_labels()`
#' call is skipped entirely when every input is a system label.
#'
#' Set `create_missing = TRUE` when applying labels from a YAML-driven
#' workflow (e.g. via `mc_md_send()`) so new project tags don't error on
#' first use. See [mc_label_ensure()] for the underlying primitive.
#'
#' @return Invisibly returns the gmailr response.
#'
#' @examples
#' \dontrun{
#' # Apply a user label
#' mc_thread_modify("18171fb2cec08e9d", add = "Clients/Acme")
#'
#' # Archive and mark read in one call
#' mc_thread_modify("18171fb2cec08e9d", remove = c("INBOX", "UNREAD"))
#'
#' # Star a thread
#' mc_thread_modify("18171fb2cec08e9d", add = "STARRED")
#'
#' # Status transition
#' mc_thread_modify("18171fb2cec08e9d", add = "Done", remove = "Pending")
#' }
#'
#' @importFrom chk chk_string chk_character chk_flag
#' @importFrom gmailr gm_labels gm_token
#' @importFrom httr POST stop_for_status content
#' @importFrom utils URLencode
#' @export
mc_thread_modify <- function(thread_id, add = NULL, remove = NULL,
                             create_missing = FALSE) {
  chk::chk_string(thread_id)
  if (!is.null(add))    chk::chk_character(add)
  if (!is.null(remove)) chk::chk_character(remove)
  chk::chk_flag(create_missing)
  if (is.null(add) && is.null(remove)) {
    stop("Provide at least one of `add` or `remove`.", call. = FALSE)
  }

  if (create_missing && !is.null(add)) {
    mc_label_ensure(add)
  }

  all_names <- c(add, remove)
  user_labels <- if (any(!all_names %in% system_labels())) {
    fetch_user_labels()
  } else {
    NULL
  }

  add_ids    <- resolve_label_names(add,    user_labels)
  remove_ids <- resolve_label_names(remove, user_labels)

  gmail_modify_thread(thread_id, add_ids, remove_ids)
}


#' POST to Gmail's threads.modify endpoint directly
#'
#' Bypasses `gmailr::gm_modify_thread()` which in gmailr 3.0.0 wraps the
#' request body in an extra list (`rename(list(...))` instead of
#' `rename(...)`), producing malformed JSON that Gmail rejects with HTTP
#' 400. Filed upstream; workaround stays until gmailr ships a fix.
#'
#' @noRd
gmail_modify_thread <- function(thread_id, add_ids, remove_ids) {
  body <- list()
  # Wrap in as.list() so jsonlite's auto_unbox (used by httr encode=json)
  # still serialises as a JSON array for length-1 vectors.
  if (length(add_ids)    > 0) body$addLabelIds    <- as.list(add_ids)
  if (length(remove_ids) > 0) body$removeLabelIds <- as.list(remove_ids)
  url <- paste0(
    "https://www.googleapis.com/gmail/v1/users/me/threads/",
    utils::URLencode(thread_id, reserved = TRUE),
    "/modify"
  )
  req <- httr::POST(url, body = body, encode = "json", gmailr::gm_token())
  httr::stop_for_status(req)
  invisible(httr::content(req, "parsed"))
}


#' Gmail system label IDs (identical to their names)
#' @noRd
system_labels <- function() {
  c("INBOX", "STARRED", "UNREAD", "IMPORTANT", "TRASH", "SPAM",
    "SENT", "DRAFT", "CHAT")
}


#' Fetch user-defined labels as a named character vector (name -> id)
#' @noRd
fetch_user_labels <- function() {
  res <- gmailr::gm_labels()
  labels <- res$labels
  user <- Filter(function(l) identical(l$type, "user"), labels)
  if (length(user) == 0) return(character(0))
  ids <- vapply(user, function(l) l$id, character(1))
  nms <- vapply(user, function(l) l$name, character(1))
  stats::setNames(ids, nms)
}


#' Resolve a vector of label names to Gmail label IDs
#'
#' System labels pass through unchanged (their ID equals their name). User
#' label names are looked up in `user_labels`; unknowns raise an error that
#' lists the available user labels.
#'
#' @param label_names Character vector of names, or `NULL`.
#' @param user_labels Named character vector (name -> id) of user labels,
#'   or `NULL` if every input is known to be a system label.
#' @return Character vector of label IDs, or `NULL` if `label_names` is `NULL`.
#' @noRd
resolve_label_names <- function(label_names, user_labels) {
  if (is.null(label_names)) return(NULL)
  sys <- system_labels()
  user_nms <- if (is.null(user_labels)) character(0) else names(user_labels)

  ids <- vapply(label_names, function(nm) {
    # System labels match case-insensitively (mirrors mc_label_ensure)
    # and normalize to the canonical uppercase ID Gmail expects.
    if (toupper(nm) %in% sys) {
      toupper(nm)
    } else if (nm %in% user_nms) {
      unname(user_labels[[nm]])
    } else {
      NA_character_
    }
  }, character(1))

  unknown <- label_names[is.na(ids)]
  if (length(unknown) > 0) {
    avail <- if (length(user_nms) == 0) {
      "(none)"
    } else {
      paste(sprintf('"%s"', user_nms), collapse = ", ")
    }
    stop(
      "Label(s) not found: ",
      paste(sprintf('"%s"', unknown), collapse = ", "),
      "\nAvailable user labels: ", avail,
      call. = FALSE
    )
  }
  unname(ids)
}
