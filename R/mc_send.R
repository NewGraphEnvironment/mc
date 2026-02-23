#' Send or draft an email from a markdown file
#'
#' The main function. Reads a markdown draft, renders to HTML, builds a
#' MIME message, and either creates a Gmail draft or sends immediately.
#'
#' Authenticates automatically if no active Gmail session is detected.
#'
#' @param path Path to the markdown draft file. Passed to [mc_md_render()].
#' @param to Recipient email address (character string or vector).
#' @param subject Email subject line.
#' @param cc Optional CC recipients (character vector). Default `NULL`.
#' @param bcc Optional BCC recipients (character vector). Default `NULL`.
#' @param from Sender address. Default `"al@newgraphenvironment.com"`.
#' @param thread_id Gmail thread ID to reply into. Default `NULL` (new thread).
#'   Use [mc_thread_find()] to look up thread IDs.
#' @param draft Logical. If `TRUE` (default), create a Gmail draft.
#'   If `FALSE`, send immediately.
#' @param test Logical. If `TRUE`, override `to` with `from` (send to self)
#'   and ignore `cc` and `thread_id`. Default `FALSE`.
#' @param sig Logical. Append signature? Passed to [mc_md_render()].
#'   Default `TRUE`.
#' @param sig_path Path to a custom signature HTML file. Default `NULL`
#'   uses the bundled New Graph signature. Passed to [mc_md_render()].
#'   Ignored when `sig = FALSE` or when `html` is provided.
#' @param html Optional pre-rendered HTML body. If provided, `path` is ignored
#'   and this HTML is used directly.
#'
#' @return Invisible `NULL`. Prints status message.
#'
#' @details
#' ## Threading
#'
#' Gmail's `gm_create_draft()` does **not** support `thread_id`. When
#' `draft = TRUE` and `thread_id` is set, `mc_send()` issues a warning
#' because the draft will not appear in the thread until manually sent
#' from the Gmail UI. Set subject to `"Re: Original Subject"` so Gmail's
#' thread-matching heuristic can place it correctly.
#'
#' When `draft = FALSE` and `thread_id` is set, the message is sent
#' directly into the thread via `gm_send_message(thread_id = ...)`.
#'
#' ## Test mode
#'
#' `test = TRUE` sends to yourself, strips CC, and ignores `thread_id`
#' to prevent accidental sends to real threads during development.
#'
#' @examples
#' \dontrun{
#' # Create a draft (safe default)
#' mc_send("communications/draft.md",
#'         to = "brandon@example.com",
#'         subject = "Cottonwood plugs")
#'
#' # Send into an existing thread
#' mc_send("communications/draft.md",
#'         to = "brandon@example.com",
#'         subject = "Re: Cottonwood plugs",
#'         thread_id = "19c05f0a98188c91",
#'         draft = FALSE)
#'
#' # Test mode — sends to self
#' mc_send("communications/draft.md",
#'         to = "brandon@example.com",
#'         subject = "Cottonwood plugs",
#'         test = TRUE)
#' }
#'
#' @export
mc_send <- function(path = NULL,
                    to,
                    subject,
                    cc = NULL,
                    bcc = NULL,
                    from = "al@newgraphenvironment.com",
                    thread_id = NULL,
                    draft = TRUE,
                    test = FALSE,
                    sig = TRUE,
                    sig_path = NULL,
                    html = NULL) {

  chk::chk_null_or(path, vld = chk::vld_string)
  chk::chk_character(to)
  chk::chk_string(subject)
  chk::chk_null_or(cc, vld = chk::vld_character)
  chk::chk_null_or(bcc, vld = chk::vld_character)
  chk::chk_string(from)
  chk::chk_null_or(thread_id, vld = chk::vld_string)
  chk::chk_flag(draft)
  chk::chk_flag(test)
  chk::chk_flag(sig)
  chk::chk_null_or(sig_path, vld = chk::vld_string)
  chk::chk_null_or(html, vld = chk::vld_string)

  # Render HTML from markdown or use pre-rendered
  if (is.null(html)) {
    if (is.null(path)) {
      stop("Provide either `path` to a markdown file or `html`.", call. = FALSE)
    }
    body_html <- mc_md_render(path, sig = sig, sig_path = sig_path)
  } else {
    body_html <- html
  }

  # Test mode: redirect to self, strip threading
  if (test) {
    to <- from
    cc <- NULL
    bcc <- NULL
    thread_id <- NULL
    message("TEST MODE: sending to ", from)
  }

  # Build MIME message
  msg <- gmailr::gm_mime()
  msg <- gmailr::gm_to(msg, to)
  msg <- gmailr::gm_from(msg, from)
  msg <- gmailr::gm_subject(msg, subject)
  msg <- gmailr::gm_html_body(msg, body_html)

  if (!is.null(cc)) {
    msg <- gmailr::gm_cc(msg, cc)
  }
  if (!is.null(bcc)) {
    msg <- gmailr::gm_bcc(msg, bcc)
  }

  # Draft or send
  if (draft) {
    if (!is.null(thread_id)) {
      warning(
        "Draft created but will NOT appear in thread. ",
        "gm_create_draft() does not support thread_id. ",
        "Use draft = FALSE to send directly into the thread, ",
        "or send the draft manually from Gmail UI.",
        call. = FALSE
      )
    }
    gmailr::gm_create_draft(msg)
    message("Draft created in Gmail. To: ", paste(to, collapse = ", "))
  } else {
    if (!is.null(thread_id)) {
      gmailr::gm_send_message(msg, thread_id = thread_id)
      message("Sent to thread ", thread_id, ". To: ", paste(to, collapse = ", "))
    } else {
      gmailr::gm_send_message(msg)
      message("Sent (new thread). To: ", paste(to, collapse = ", "))
    }
  }

  invisible(NULL)
}
