#' Send an email from a markdown file
#'
#' Sends immediately. To produce a Gmail draft for review instead, use
#' [mc_draft()].
#'
#' The verb lives in the function name deliberately. An earlier API selected
#' send-vs-draft with a `draft` argument, which meant one character separated a
#' reversible act from an irreversible one — and did, once, deliver a message to
#' external recipients when a draft was intended. There is no `draft` argument
#' here; sending is named, not configured (#39).
#'
#' Authenticates automatically if no active Gmail session is detected.
#'
#' @param path Path to the markdown draft file. Passed to [mc_md_render()].
#' @param to Recipient email address (character string or vector).
#' @param subject Email subject line.
#' @param cc Optional CC recipients (character vector). Default `NULL`.
#' @param bcc Optional BCC recipients (character vector). Default `NULL`.
#' @param from Sender address. Default uses `getOption("mc.from")`,
#'   then the `MC_FROM` environment variable. Errors if neither is set.
#' @param thread_id Gmail thread ID to reply into. Default `NULL` (new thread).
#'   Use [mc_thread_find()] to look up thread IDs.
#' @param to_self Logical. If `TRUE`, override `to` with `from` and drop `cc`,
#'   `bcc` and `thread_id`, so the message reaches nobody but the sender.
#'   Default `FALSE`. This caps who receives the message; it does not stop the
#'   send. Use [mc_draft()] if you do not want a message delivered at all.
#' @param sig Logical. Append signature? Passed to [mc_md_render()].
#'   Default `TRUE`.
#' @param sig_path Path to a custom signature HTML file. Default `NULL`
#'   uses the bundled New Graph signature. Passed to [mc_md_render()].
#'   Ignored when `sig = FALSE` or when `html` is provided.
#' @param attachments Optional character vector of file paths to attach.
#'   Each file is attached via [gmailr::gm_attach_file()]. Default `NULL`.
#' @param labels Optional character vector of Gmail label names to apply
#'   to the resulting thread. Applied via [mc_thread_modify()] after a
#'   successful send.
#' @param labels_create Logical. When `TRUE` (default), missing user
#'   labels in `labels` are auto-created via [mc_label_ensure()].
#' @param html Optional pre-rendered HTML body. If provided, `path` is ignored
#'   and this HTML is used directly.
#' @param send_at Schedule the email for later. Either a `POSIXct` datetime
#'   or a numeric number of minutes from now. Default `NULL` (send now).
#'   Scheduling is inherently a send, which is why it lives here and not on
#'   [mc_draft()].
#' @param scheduler Backend for scheduled send. One of `"callr"` (default),
#'   `"auto"` (OS-native: `launchd` on macOS, `at` on Linux), `"launchd"`, or
#'   `"at"`. Ignored when `send_at` is `NULL`.
#'
#' @return The Gmail thread ID of the sent message, invisibly. When `send_at`
#'   is set, returns a backend-specific scheduler handle invisibly instead.
#'
#' @seealso [mc_draft()] to create a draft, [mc_md_send()] to send from
#'   frontmatter.
#'
#' @examples
#' \dontrun{
#' mc_send("communications/newsletter.md",
#'         to = "someone@example.com",
#'         subject = "Spring newsletter")
#'
#' # Check the rendering in a real inbox without involving anyone else
#' mc_send("communications/newsletter.md",
#'         to = "someone@example.com",
#'         subject = "Spring newsletter",
#'         to_self = TRUE)
#'
#' # Reply into an existing thread
#' mc_send("communications/reply.md",
#'         to = "someone@example.com",
#'         subject = "Re: Spring newsletter",
#'         thread_id = "19c05f0a98188c91")
#' }
#'
#' @export
mc_send <- function(path = NULL,
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
                    send_at = NULL,
                    scheduler = c("callr", "auto", "launchd", "at")) {
  mc_deliver(
    path = path, to = to, subject = subject, cc = cc, bcc = bcc, from = from,
    thread_id = thread_id, to_self = to_self, sig = sig, sig_path = sig_path,
    attachments = attachments, labels = labels, labels_create = labels_create,
    html = html, send_at = send_at, scheduler = scheduler,
    .draft = FALSE
  )
}
