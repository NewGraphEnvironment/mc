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
#' @param send_at Schedule the email for later. Either a `POSIXct` datetime
#'   or a numeric number of minutes from now. Default `NULL` (send/draft
#'   immediately). When set, `draft` is forced to `FALSE` and the email is
#'   sent in a background R process via [callr::r_bg()]. Requires the
#'   **callr** package.
#'
#' @return When `send_at` is `NULL`, invisible `NULL`. When `send_at` is set,
#'   returns the [callr::r_bg()] process handle invisibly. Use `$is_alive()`
#'   to check status or `$kill()` to cancel.
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
#'
#' # Send in 10 minutes
#' proc <- mc_send("communications/draft.md",
#'                 to = "brandon@example.com",
#'                 subject = "Cottonwood plugs",
#'                 send_at = 10)
#' proc$is_alive()  # check if still waiting
#' proc$kill()      # cancel
#'
#' # Send at a specific time
#' mc_send("communications/draft.md",
#'         to = "brandon@example.com",
#'         subject = "Cottonwood plugs",
#'         send_at = as.POSIXct("2026-02-24 09:11:00"))
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
                    html = NULL,
                    send_at = NULL) {

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

  # Scheduled send — defer to background process
  if (!is.null(send_at)) {
    if (!requireNamespace("callr", quietly = TRUE)) {
      stop("The callr package is required for send_at. Install with pak::pak('callr').",
           call. = FALSE)
    }
    delay_secs <- resolve_send_at(send_at)
    send_time <- Sys.time() + delay_secs
    message(
      "Scheduled to send at ", format(send_time, "%Y-%m-%d %H:%M:%S"),
      " (", round(delay_secs / 60, 1), " min from now)",
      "\nTo: ", paste(to, collapse = ", ")
    )
    proc <- callr::r_bg(
      function(delay, path, to, subject, cc, bcc, from,
               thread_id, test, sig, sig_path, html) {
        Sys.sleep(delay)
        mc::mc_send(
          path = path, to = to, subject = subject,
          cc = cc, bcc = bcc, from = from,
          thread_id = thread_id, draft = FALSE,
          test = test, sig = sig, sig_path = sig_path,
          html = html, send_at = NULL
        )
      },
      args = list(
        delay = delay_secs, path = path, to = to,
        subject = subject, cc = cc, bcc = bcc, from = from,
        thread_id = thread_id, test = test, sig = sig,
        sig_path = sig_path, html = html
      ),
      package = "mc"
    )
    return(invisible(proc))
  }

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


#' Convert send_at value to delay in seconds
#' @param send_at POSIXct datetime or numeric minutes from now.
#' @return Numeric delay in seconds.
#' @noRd
resolve_send_at <- function(send_at) {
  if (inherits(send_at, "POSIXct")) {
    delay <- as.numeric(difftime(send_at, Sys.time(), units = "secs"))
  } else if (is.numeric(send_at) && length(send_at) == 1) {
    delay <- send_at * 60
  } else {
    stop(
      "`send_at` must be a POSIXct datetime or numeric minutes from now.",
      call. = FALSE
    )
  }
  if (delay <= 0) {
    stop("`send_at` must be in the future.", call. = FALSE)
  }
  delay
}
