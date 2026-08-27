#' Create a Gmail draft from a markdown file
#'
#' Creates a draft for review. Nothing passed to this function sends — to
#' deliver a message, call [mc_send()].
#'
#' @inheritParams mc_send
#' @param to_self Logical. If `TRUE`, address the draft to `from` and drop
#'   `cc`, `bcc` and `thread_id`. Default `FALSE`.
#'
#' @return The Gmail thread ID of the resulting draft, invisibly. May be `NULL`
#'   if the gmailr response did not include one.
#'
#' @details
#' `gmailr::gm_create_draft()` does not accept a `thread_id`, so drafts always
#' land outside the conversation. Supplying `thread_id` warns. Either move the
#' draft into the thread from the Gmail UI before sending, or use [mc_send()]
#' to deliver straight into the thread.
#'
#' `send_at` and `scheduler` are not accepted here. A scheduled message is by
#' definition one that gets sent, so scheduling lives on [mc_send()].
#'
#' @seealso [mc_send()] to send, [mc_md_draft()] to draft from frontmatter.
#'
#' @examples
#' \dontrun{
#' mc_draft("communications/newsletter.md",
#'          to = "someone@example.com",
#'          subject = "Spring newsletter")
#'
#' # Draft addressed to yourself, to check the rendering
#' mc_draft("communications/newsletter.md",
#'          to = "someone@example.com",
#'          subject = "Spring newsletter",
#'          to_self = TRUE)
#' }
#'
#' @export
mc_draft <- function(path = NULL,
                     to,
                     subject,
                     cc = NULL,
                     bcc = NULL,
                     from = default_from(),
                     thread_id = NULL,
                     to_self = FALSE,
                     sig = TRUE,
                     sig_path = NULL,
                     attachments = NULL,
                     labels = NULL,
                     labels_create = TRUE,
                     html = NULL,
                     ...) {
  # send_at/scheduler are rejected rather than silently ignored: a caller who
  # reaches for them wants delivery, and quietly handing back a draft would
  # look like a scheduled send that never fired.
  extra <- list(...)
  bad <- intersect(names(extra), c("send_at", "scheduler"))
  if (length(bad) > 0) {
    stop(
      "`", paste(bad, collapse = "`, `"), "` cannot be used with mc_draft() — ",
      "a scheduled message is one that gets sent. Use mc_send(", bad[1],
      " = ...) instead.",
      call. = FALSE
    )
  }
  if (length(extra) > 0) {
    stop(
      "unused argument(s): ", paste(names(extra), collapse = ", "),
      call. = FALSE
    )
  }
  mc_deliver(
    path = path, to = to, subject = subject, cc = cc, bcc = bcc, from = from,
    thread_id = thread_id, to_self = to_self, sig = sig, sig_path = sig_path,
    attachments = attachments, labels = labels, labels_create = labels_create,
    html = html, send_at = NULL, scheduler = "callr",
    .draft = TRUE
  )
}
