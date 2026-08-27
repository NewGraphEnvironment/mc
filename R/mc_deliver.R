#' Build and deliver a message (internal)
#'
#' Shared implementation behind [mc_draft()] and [mc_send()]. Renders the body,
#' builds the MIME message, and either creates a Gmail draft or sends,
#' according to `.draft`.
#'
#' Not exported. The exported wrappers each fix `.draft`, which is what makes
#' "nothing passed to `mc_draft()` can send" true by construction rather than
#' by convention (#39).
#'
#' @inheritParams mc_send
#' @param .draft Logical. `TRUE` creates a Gmail draft, `FALSE` sends.
#'   Supplied by the wrapper, never by the caller.
#' @return Gmail thread ID, invisibly.
#' @keywords internal
#' @importFrom chk chk_null_or chk_character chk_string chk_flag vld_string
#'   vld_character
#' @importFrom gmailr gm_mime gm_to gm_from gm_subject gm_html_body gm_cc
#'   gm_bcc gm_create_draft gm_send_message gm_attach_file
mc_deliver <- function(path = NULL,
                    to,
                    subject,
                    cc = NULL,
                    bcc = NULL,
                    from = default_from(),
                    thread_id = NULL,
                    .draft,
                    to_self = FALSE,
                    sig = TRUE,
                    sig_path = NULL,
                    attachments = NULL,
                    labels = NULL,
                    labels_create = TRUE,
                    html = NULL,
                    send_at = NULL,
                    scheduler = c("callr", "auto", "launchd", "at")) {

  scheduler <- match.arg(scheduler)

  chk::chk_null_or(path, vld = chk::vld_string)
  chk::chk_character(to)
  chk::chk_string(subject)
  chk::chk_null_or(cc, vld = chk::vld_character)
  chk::chk_null_or(bcc, vld = chk::vld_character)
  chk::chk_string(from)
  chk::chk_null_or(thread_id, vld = chk::vld_string)
  chk::chk_flag(.draft)
  chk::chk_flag(to_self)
  chk::chk_flag(sig)
  chk::chk_null_or(sig_path, vld = chk::vld_string)
  chk::chk_null_or(attachments, vld = chk::vld_character)
  chk::chk_null_or(labels, vld = chk::vld_character)
  chk::chk_flag(labels_create)
  chk::chk_null_or(html, vld = chk::vld_string)

  # Validate attachment files exist
  if (!is.null(attachments)) {
    missing <- attachments[!file.exists(attachments)]
    if (length(missing) > 0) {
      stop(
        "Attachment file(s) not found: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
  }

  # Render HTML up front (before any scheduling dispatch) so the body
  # travels with `args` to the scheduler backend — avoids re-reading the
  # markdown at fire time (path may have moved, body may have changed)
  # and means the launchd plist's R invocation does not need filesystem
  # access to the original draft.
  if (is.null(html)) {
    if (is.null(path)) {
      stop("Provide either `path` to a markdown file or `html`.", call. = FALSE)
    }
    html <- mc_md_render(path, sig = sig, sig_path = sig_path)
  }

  # Scheduled send — defer to backend dispatcher
  if (!is.null(send_at)) {
    if (scheduler == "callr") {
      warning(
        "scheduler = \"callr\" scheduled-send is unreliable in some call ",
        "contexts (Rscript one-shot, RStudio sessions that exit, CI). The ",
        "callr background process can be cleaned up before fire time, ",
        "silently dropping the send. Heartbeat log entries (SCHEDULED at ",
        "submission, STARTED at fire) make missed fires auditable from ",
        "~/.mc/send_log.txt. Use scheduler = \"auto\" for OS-native ",
        "scheduling (launchd / at) — see ",
        "https://github.com/NewGraphEnvironment/mc/issues/36",
        call. = FALSE
      )
    }
    send_time <- resolve_send_at(send_at)
    delay_min <- as.numeric(difftime(send_time, Sys.time(), units = "mins"))
    message(
      "Scheduled to send at ", format(send_time, "%Y-%m-%d %H:%M:%S"),
      " (", round(delay_min, 1), " min from now)",
      "\nTo: ", paste(to, collapse = ", ")
    )
    send_log(
      subject, to, "SCHEDULED",
      paste0("target=", format(send_time, "%Y-%m-%d %H:%M:%S"),
             " scheduler=", scheduler)
    )
    schedule_args <- list(
      to = to, subject = subject, cc = cc, bcc = bcc, from = from,
      thread_id = thread_id, to_self = to_self, sig = sig,
      sig_path = sig_path, attachments = attachments, labels = labels,
      labels_create = labels_create, html = html
    )
    handle <- schedule_send(send_time, schedule_args, scheduler = scheduler)
    return(invisible(handle))
  }

  # Test mode: redirect to self, strip threading
  if (to_self) {
    to <- from
    cc <- NULL
    bcc <- NULL
    thread_id <- NULL
    message("TO SELF: addressed to ", from)
  }

  # Build MIME message
  msg <- gmailr::gm_mime()
  msg <- gmailr::gm_to(msg, to)
  msg <- gmailr::gm_from(msg, from)
  msg <- gmailr::gm_subject(msg, subject)
  msg <- gmailr::gm_html_body(msg, html)

  if (!is.null(cc)) {
    msg <- gmailr::gm_cc(msg, cc)
  }
  if (!is.null(bcc)) {
    msg <- gmailr::gm_bcc(msg, bcc)
  }
  if (!is.null(attachments)) {
    for (file_path in attachments) {
      msg <- gmailr::gm_attach_file(msg, file_path)
    }
  }

  # Draft or send — capture thread_id from gmailr response
  if (.draft) {
    if (!is.null(thread_id)) {
      warning(
        "Draft created but will NOT appear in thread. ",
        "gm_create_draft() does not support thread_id. ",
        "Use mc_send() to deliver straight into the thread, ",
        "or send the draft manually from Gmail UI.",
        call. = FALSE
      )
    }
    res <- gmailr::gm_create_draft(msg)
    sent_thread_id <- extract_thread_id(res)
    message("Draft created in Gmail. To: ", paste(to, collapse = ", "))
  } else {
    if (!is.null(thread_id)) {
      res <- gmailr::gm_send_message(msg, thread_id = thread_id)
      message("Sent to thread ", thread_id, ". To: ", paste(to, collapse = ", "))
    } else {
      res <- gmailr::gm_send_message(msg)
      message("Sent (new thread). To: ", paste(to, collapse = ", "))
    }
    sent_thread_id <- extract_thread_id(res)
  }

  # Apply labels to the draft or sent thread.
  # Wrapped in tryCatch so a label failure (unknown name, network error, auth
  # blip) does not cascade into an error on a draft/send that already
  # succeeded — the user would otherwise be left with a sent email but no
  # labels and no clear recovery path. Failures degrade to a warning that
  # surfaces the thread_id so the user can retry mc_thread_modify() manually.
  if (!is.null(labels)) {
    if (is.null(sent_thread_id)) {
      warning(
        "Labels not applied: gmailr response did not include a threadId.",
        call. = FALSE
      )
    } else {
      thread_label_target <- if (.draft) "draft thread" else "thread"
      tryCatch(
        {
          mc_thread_modify(sent_thread_id, add = labels,
                           create_missing = labels_create)
          message(
            "Labels applied to ", thread_label_target, " ", sent_thread_id,
            ": ", paste(labels, collapse = ", ")
          )
        },
        error = function(e) {
          warning(
            "Labels not applied to ", thread_label_target, " ",
            sent_thread_id, ": ", conditionMessage(e),
            "\nRetry manually with mc_thread_modify(\"", sent_thread_id,
            "\", add = c(\"", paste(labels, collapse = "\", \""), "\")).",
            call. = FALSE
          )
        }
      )
    }
  }

  invisible(sent_thread_id)
}



#' Pull threadId out of a gmailr draft or message resource
#'
#' Drafts nest the message under `$message`; sent messages have it at the top
#' level. Returns `NULL` if no threadId is present (e.g. mocked test stubs).
#' @noRd
extract_thread_id <- function(res) {
  if (is.null(res)) return(NULL)
  if (!is.null(res$threadId)) return(res$threadId)
  if (!is.null(res$message) && !is.null(res$message$threadId)) {
    return(res$message$threadId)
  }
  NULL
}


#' Prevent idle sleep on macOS while a scheduled send is waiting
#'
#' Runs `caffeinate -i -w <pid>` in the background. Caffeinate exits
#' automatically when the target process exits. No-op on non-macOS systems.
#' @param proc A callr process handle.
#' @noRd
caffeinate_send <- function(proc) {
  if (Sys.info()[["sysname"]] != "Darwin") return(invisible(NULL))
  pid <- proc$get_pid()
  system2("caffeinate", args = c("-i", "-w", pid), wait = FALSE,
          stdout = FALSE, stderr = FALSE)
  message("caffeinate active (PID ", pid, ") — machine will stay awake")
  invisible(NULL)
}


#' Log a scheduled send outcome to ~/.mc/send_log.txt
#'
#' Appends one line per event. Creates the directory if needed.
#' @param subject Email subject.
#' @param to Recipient(s).
#' @param status One of "SCHEDULED", "STARTED", "SENT", "SKIPPED", "FAILED".
#' @param detail Optional detail message.
#' @noRd
send_log <- function(subject, to, status, detail = "") {
  log_dir <- file.path(Sys.getenv("HOME"), ".mc")
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  line <- paste0(
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ",
    status, " | ",
    "To: ", paste(to, collapse = ", "), " | ",
    "Subject: ", subject,
    if (nzchar(detail)) paste0(" | ", detail) else ""
  )
  cat(line, "\n", file = file.path(log_dir, "send_log.txt"), append = TRUE)
}


#' Show a macOS desktop notification for scheduled send outcomes
#'
#' Uses `osascript` to display a notification. No-op on non-macOS systems.
#' @param title Notification title.
#' @param body Notification body.
#' @noRd
send_notify <- function(title, body) {
  if (Sys.info()[["sysname"]] != "Darwin") return(invisible(NULL))
  script <- paste0(
    'display notification "', gsub('"', '\\\\"', body),
    '" with title "mc" subtitle "', gsub('"', '\\\\"', title), '"'
  )
  tryCatch(
    system2("osascript", args = c("-e", script), stdout = FALSE, stderr = FALSE),
    error = function(e) NULL
  )
  invisible(NULL)
}


#' Convert send_at value to a target POSIXct time
#' @param send_at POSIXct datetime or numeric minutes from now.
#' @return POSIXct target time.
#' @noRd
resolve_send_at <- function(send_at) {
  if (inherits(send_at, "POSIXct")) {
    target <- send_at
  } else if (is.numeric(send_at) && length(send_at) == 1) {
    target <- Sys.time() + send_at * 60
  } else {
    stop(
      "`send_at` must be a POSIXct datetime or numeric minutes from now.",
      call. = FALSE
    )
  }
  if (target <= Sys.time()) {
    stop("`send_at` must be in the future.", call. = FALSE)
  }
  target
}
