#' Create a Gmail draft from a markdown file
#'
#' Creates a draft for review. Nothing passed to this function sends — to
#' deliver a message, call [mc_send()].
#'
#' @inheritParams mc_send
#' @param to_self Logical. If `TRUE`, address the draft to `from` and drop
#'   `cc`, `bcc` and `thread_id`. Default `FALSE`.
#' @param draft_id `NULL` (default) to create a new draft, or the id of a draft
#'   to replace in place, as returned in `draft_id` by an earlier call. Only
#'   that draft changes, and it keeps its id. If Gmail does not know the id
#'   (the draft was sent or deleted, or the id is not a draft id), a warning is
#'   given and a new draft is created.
#' @param ... Not used. Present only so that passing `send_at` or `scheduler`
#'   errors with a pointer to [mc_send()] rather than R's generic unused-argument
#'   error. Any other argument errors as unused.
#'
#' @return A list, invisibly, with `draft_id` (pass it back as `draft_id` to
#'   replace this draft), `thread_id` and `message_id`. `draft_id` stays the
#'   same across replacements; `message_id` is the Gmail API id of the draft's
#'   current message (not its `Message-ID` header) and changes on each
#'   replacement. An element is `NULL` when Gmail's response did not include
#'   it.
#'
#' @details
#' With `thread_id`, the draft is created in that conversation, ready to
#' review and send from the thread, and carries the reply headers described
#' in [mc_send()]. Gmail decides whether a draft joins a thread; if it puts
#' the draft somewhere else, a warning says so.
#'
#' mc never deletes a draft. To regenerate one (a re-rendered attachment, an
#' edited body), pass the `draft_id` it returned; nothing else in the mailbox
#' is touched. Replacing overwrites the draft as it stands, including any
#' edits made to it in Gmail. Pass the same `thread_id` and `labels` as when
#' the draft was made: a replacement without `thread_id` takes the draft out of
#' its thread, and labels not given again are dropped.
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
#' # Replace that draft after editing the file: same draft, same id
#' d <- mc_draft("communications/newsletter.md",
#'               to = "someone@example.com",
#'               subject = "Spring newsletter")
#' mc_draft("communications/newsletter.md",
#'          to = "someone@example.com",
#'          subject = "Spring newsletter",
#'          draft_id = d$draft_id)
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
                     draft_id = NULL,
                     to_self = FALSE,
                     sig = TRUE,
                     sig_path = NULL,
                     attachments = NULL,
                     inline_images = NULL,
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
      "`", paste(bad, collapse = "`, `"), "` cannot be used with mc_draft() - ",
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
    thread_id = thread_id, draft_id = draft_id, to_self = to_self, sig = sig,
    sig_path = sig_path,
    attachments = attachments, inline_images = inline_images,
    labels = labels, labels_create = labels_create,
    html = html, send_at = NULL, scheduler = "callr",
    .draft = TRUE
  )
}
