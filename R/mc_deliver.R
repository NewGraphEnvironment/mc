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
#' @param draft_id `NULL`, or the id of a draft to replace in place. Drafts
#'   only.
#' @return For a send, the Gmail thread ID, invisibly. For a draft, a list with
#'   `draft_id`, `thread_id` and `message_id`, invisibly.
#' @keywords internal
#' @importFrom chk chk_null_or chk_character chk_string chk_flag vld_string
#'   vld_character
#' @importFrom gmailr gm_mime gm_to gm_from gm_subject gm_html_body gm_cc
#'   gm_bcc gm_create_draft gm_send_message gm_attach_file gm_attach_part
mc_deliver <- function(path = NULL,
                       to,
                       subject,
                       cc = NULL,
                       bcc = NULL,
                       from = default_from(),
                       thread_id = NULL,
                       draft_id = NULL,
                       .draft,
                       to_self = FALSE,
                       sig = TRUE,
                       sig_path = NULL,
                       attachments = NULL,
                       inline_images = NULL,
                       labels = NULL,
                       labels_create = TRUE,
                       html = NULL,
                       send_at = NULL,
                       scheduler = NULL) {

  scheduler <- if (is.null(scheduler)) {
    default_scheduler()
  } else {
    match.arg(scheduler, c("auto", "callr", "launchd", "at"))
  }

  # Before the chk block: `from` defaults to default_from(), and chk_string(from)
  # forces it. A call missing its body is an argument error, and it should be
  # reported as one even where no sender is configured (#47).
  if (is.null(html) && is.null(path)) {
    stop("Provide either `path` to a markdown file or `html`.", call. = FALSE)
  }

  chk::chk_null_or(path, vld = chk::vld_string)
  chk::chk_character(to)
  chk::chk_string(subject)
  chk::chk_null_or(cc, vld = chk::vld_character)
  chk::chk_null_or(bcc, vld = chk::vld_character)
  chk::chk_string(from)
  chk::chk_null_or(thread_id, vld = chk::vld_string)
  chk::chk_null_or(draft_id, vld = chk::vld_string)
  chk::chk_flag(.draft)
  if (identical(draft_id, "")) stop("`draft_id` must not be empty.", call. = FALSE)
  if (!is.null(draft_id) && !.draft) {
    stop("`draft_id` applies to drafts only.", call. = FALSE)
  }
  chk::chk_flag(to_self)
  chk::chk_flag(sig)
  chk::chk_null_or(sig_path, vld = chk::vld_string)
  chk::chk_null_or(attachments, vld = chk::vld_character)
  chk::chk_null_or(inline_images, vld = chk::vld_character)
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
    html <- mc_md_render(path, sig = sig, sig_path = sig_path)
  }

  check_inline_images(inline_images, html)

  # Scheduled send — defer to backend dispatcher
  if (!is.null(send_at)) {
    if (scheduler == "callr") {
      warning(
        "scheduler = \"callr\" scheduled-send is unreliable in some call ",
        "contexts (Rscript one-shot, RStudio sessions that exit, CI). The ",
        "callr background process can be cleaned up before fire time, ",
        "silently dropping the send. Heartbeat log entries (SCHEDULED at ",
        "submission, STARTED at fire) make missed fires auditable from ",
        "~/.mc/send_log.txt. On macOS and Linux, scheduler = \"auto\" ",
        "(the default there) uses OS-native scheduling (launchd / at) - see ",
        "https://github.com/NewGraphEnvironment/mc/issues/36",
        call. = FALSE
      )
    }
    send_time <- resolve_send_at(send_at)
    delay_min <- as.numeric(difftime(send_time, Sys.time(), units = "mins"))
    # In this process's zone, with the zone named, so it reads correctly beside
    # send log lines a launchd job later writes in the system zone.
    target_label <- format(send_time, "%Y-%m-%d %H:%M:%S %Z", tz = "")
    message(
      "Scheduled to send at ", target_label,
      " (", round(delay_min, 1), " min from now)",
      "\nTo: ", paste(to, collapse = ", ")
    )
    send_log(
      subject, to, "SCHEDULED",
      paste0("target=", target_label,
             " scheduler=", scheduler)
    )
    # The send runs later in another process: a launchd job starts in `/`, so
    # a relative attachment path that resolves here would not resolve there.
    # Only the directory is resolved: gmailr names the attachment after the
    # basename, which normalizePath() would change through a symlink.
    if (!is.null(attachments)) {
      attachments <- file.path(
        normalizePath(dirname(attachments), mustWork = TRUE),
        basename(attachments)
      )
    }
    # Normalised here, not inside the list() below: the scheduled-args guard
    # test reads the field names out of that list() call.
    if (!is.null(inline_images)) {
      inline_images <- stats::setNames(
        file.path(
          normalizePath(dirname(inline_images), mustWork = TRUE),
          basename(inline_images)
        ),
        names(inline_images)
      )
    }
    schedule_args <- list(
      to = to, subject = subject, cc = cc, bcc = bcc, from = from,
      thread_id = thread_id, to_self = to_self, sig = sig,
      sig_path = sig_path, attachments = attachments,
      inline_images = inline_images, labels = labels,
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

  # A reply names the message it answers, so recipients' clients thread it
  # too, and carries a "Re: " subject. Read here, after to_self has dropped
  # thread_id and after the scheduling branch, so a scheduled send reads the
  # thread when it fires (#55).
  reply <- list()
  if (!is.null(thread_id)) {
    reply <- reply_headers(thread_id)
    if (!grepl("^\\s*re:", subject, ignore.case = TRUE)) {
      subject <- paste0("Re: ", subject)
    }
  }

  # Build MIME message
  msg <- gmailr::gm_mime()
  msg <- gmailr::gm_to(msg, to)
  msg <- gmailr::gm_from(msg, from)
  msg <- gmailr::gm_subject(msg, subject)
  for (h in names(reply)) msg$header[[h]] <- reply[[h]]
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
  # Inline images: a part with Content-Id <name> and inline disposition, which
  # the HTML references as src="cid:<name>". Kept under to_self, since that is
  # how the rendering gets checked.
  for (cid in names(inline_images)) {
    file_path <- inline_images[[cid]]
    msg <- gmailr::gm_attach_part(
      msg, readBin(file_path, "raw", file.info(file_path)$size),
      id = cid, content_type = mime::guess_type(file_path),
      name = basename(file_path), filename = basename(file_path),
      disposition = "inline"
    )
  }

  # Draft or send — capture thread_id from gmailr response
  if (.draft) {
    written <- write_draft(msg, thread_id = thread_id, draft_id = draft_id)
    res <- written$res
    sent_thread_id <- extract_thread_id(res)
    where <- if (is.null(thread_id)) "" else paste0(" in thread ", thread_id)
    if (written$updated) {
      message("Draft ", draft_id, " replaced", where, ". To: ", paste(to, collapse = ", "))
    } else {
      message("Draft created", where, ". To: ", paste(to, collapse = ", "))
    }
    # Gmail places a draft in a thread only when it accepts the reply (the
    # subject has to fit), and does not say when it declines.
    if (!is.null(thread_id) && !is.null(sent_thread_id) &&
          !identical(sent_thread_id, thread_id)) {
      warning(
        "Gmail placed the draft in thread ", sent_thread_id, ", not ",
        thread_id, ". Check the subject matches the conversation.",
        call. = FALSE
      )
    }
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

  if (.draft) {
    return(invisible(list(
      draft_id = res[["id"]],
      thread_id = sent_thread_id,
      message_id = res[["message"]][["id"]]
    )))
  }
  invisible(sent_thread_id)
}


#' Create a draft, or replace one in place by its id (internal)
#'
#' With no `draft_id` and no `thread_id`, the draft is created through
#' [gmailr::gm_create_draft()], unchanged. A `thread_id` places it in that
#' thread, which gmailr cannot do, so it goes through Gmail's API directly.
#' With a `draft_id`, that draft, and only that draft, is replaced through
#' Gmail's `drafts.update`, so its id stays the same. A `draft_id` Gmail no
#' longer knows (the draft was sent or deleted) warns and creates a new draft,
#' in the same thread. Nothing here deletes a draft.
#'
#' @param msg A gmailr mime object.
#' @param thread_id `NULL` or the thread to place the draft in.
#' @param draft_id `NULL` or a draft id.
#' @return List: `res`, the Gmail draft resource; `updated`, `TRUE` when an
#'   existing draft was replaced.
#' @noRd
write_draft <- function(msg, thread_id = NULL, draft_id = NULL) {
  if (!is.null(draft_id)) {
    res <- tryCatch(
      gmail_draft_request(as.character(msg), thread_id = thread_id,
                          draft_id = draft_id),
      mc_draft_not_found = function(e) NULL
    )
    if (!is.null(res)) return(list(res = res, updated = TRUE))
    warning(
      "Draft ", draft_id, " was not found in Gmail (sent or deleted). ",
      "Creating a new draft.",
      call. = FALSE
    )
  }
  res <- if (is.null(thread_id)) {
    gmailr::gm_create_draft(msg)
  } else {
    gmail_draft_request(as.character(msg), thread_id = thread_id)
  }
  list(res = res, updated = FALSE)
}


#' Reply headers for a message going into a thread (internal)
#'
#' `In-Reply-To` names the thread's latest message (not a draft, not trashed
#' or spam), and `References` is that message's `References` (or, lacking
#' one, its `In-Reply-To`) followed by its `Message-ID`. Long chains keep the
#' first id and the last ten, so the header stays well under the 998-character
#' line limit.
#'
#' @param thread_id Gmail thread ID.
#' @return Named list of header values, or an empty list (with a warning) when
#'   the thread has no message with a `Message-ID` to answer. Errors when the
#'   thread cannot be read, before anything is created or sent.
#' @noRd
reply_headers <- function(thread_id) {
  thread <- tryCatch(
    gmailr::gm_thread(id = thread_id),
    error = function(e) {
      stop("Could not read thread ", thread_id, " to reply into it: ",
           conditionMessage(e), call. = FALSE)
    }
  )
  msgs <- Filter(function(m) {
    !any(c("DRAFT", "TRASH", "SPAM") %in% unlist(m$labelIds))
  }, thread$messages %||% list())
  mid <- if (length(msgs)) extract_header(msgs[[length(msgs)]], "Message-ID") else NA
  if (is.na(mid) || !nzchar(trimws(mid))) {
    warning(
      "Thread ", thread_id, " has no message with a Message-ID to reply to. ",
      "Threading by Gmail thread id only.",
      call. = FALSE
    )
    return(list())
  }
  mid <- trimws(mid)
  parent <- msgs[[length(msgs)]]
  prior <- extract_header(parent, "References")
  if (is.na(prior)) prior <- extract_header(parent, "In-Reply-To")
  ids <- if (is.na(prior)) character() else regmatches(prior, gregexpr("<[^<>]+>", prior))[[1]]
  ids <- c(ids, mid)
  if (length(ids) > 11) ids <- c(ids[1], utils::tail(ids, 10))
  list(`In-Reply-To` = mid, References = paste(ids, collapse = " "))
}


#' Create or update a Gmail draft through the API directly (internal)
#'
#' gmailr 3.0.0 has no `drafts.update`, and its `gm_create_draft()` cannot
#' place a draft in a thread. This sends the draft resource as JSON, the shape
#' [gmailr::gm_send_message()] uses for a send: `POST drafts` to create,
#' `PUT drafts/{id}` to replace.
#'
#' @param raw The RFC 822 message, as a string.
#' @param thread_id `NULL` or the thread to place the draft in.
#' @param draft_id `NULL` to create, or the id of the draft to replace.
#' @return The Gmail draft resource, a list.
#' @noRd
gmail_draft_request <- function(raw, thread_id = NULL, draft_id = NULL) {
  message_part <- list(raw = base64url_padded(raw))
  if (!is.null(thread_id)) message_part$threadId <- thread_id
  body <- list(message = message_part)
  url <- "https://www.googleapis.com/gmail/v1/users/me/drafts"
  json <- jsonlite::toJSON(body, auto_unbox = TRUE)
  if (is.null(draft_id)) {
    req <- httr::POST(url, body = json, httr::content_type_json(),
                      gmailr::gm_token())
  } else {
    body$id <- draft_id
    json <- jsonlite::toJSON(body, auto_unbox = TRUE)
    req <- httr::PUT(
      paste0(url, "/", utils::URLencode(draft_id, reserved = TRUE)),
      body = json, httr::content_type_json(), gmailr::gm_token()
    )
    if (httr::status_code(req) == 404) {
      stop(structure(
        class = c("mc_draft_not_found", "error", "condition"),
        list(message = paste0("Draft not found: ", draft_id), call = NULL)
      ))
    }
  }
  httr::stop_for_status(req)
  httr::content(req, "parsed")
}


#' Base64url with padding, on one line (internal)
#'
#' The encoding [gmailr::gm_send_message()] gives a message's `raw` field.
#' `jsonlite::base64url_enc()` wraps lines and drops the padding.
#' @param x A string.
#' @return A string.
#' @noRd
base64url_padded <- function(x) {
  enc <- gsub("\n", "", jsonlite::base64url_enc(x))
  pad <- (4 - nchar(enc) %% 4) %% 4
  paste0(enc, strrep("=", pad))
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
  message("caffeinate active (PID ", pid, ") - machine will stay awake")
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
    # Zone named: lines come from the scheduling session and from the fired
    # job, whose zones can differ.
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), " | ",
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


#' Check inline images against the HTML that references them (internal)
#'
#' Each name must be a usable Content-ID token and each path must exist. A
#' `cid:` in the HTML with no matching image is an error, because the reader
#' would see a broken image; an image the HTML never references is a warning.
#'
#' @param inline_images Named character vector, name = Content-ID, value = path.
#' @param html The HTML body.
#' @return `NULL`, invisibly. Called for its errors and warnings.
#' @keywords internal
check_inline_images <- function(inline_images, html) {
  # A reference is what a client draws: a src or background attribute, or a
  # CSS url() in a style attribute, read from tags only, so "cid:" in prose,
  # in a code span or inside another attribute's value is not one, nor is
  # data-src.
  refs <- cid_refs(html)
  refs <- unique(refs)
  if (is.null(inline_images)) {
    if (length(refs)) stop("HTML references cid: ", paste(refs, collapse = ", "),
                           " but no inline_images were given.", call. = FALSE)
    return(invisible(NULL))
  }
  ids <- names(inline_images)
  if (is.null(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop("inline_images must be named, with a unique Content-ID for each image.", call. = FALSE)
  }
  bad <- ids[!grepl("^[A-Za-z0-9._@-]+$", ids)]
  if (length(bad)) stop("Invalid Content-ID name(s): ", paste(bad, collapse = ", "),
                        ". Use letters, digits and . _ @ -", call. = FALSE)
  missing <- inline_images[!file.exists(inline_images)]
  if (length(missing)) stop("Inline image file(s) not found: ", paste(missing, collapse = ", "), call. = FALSE)
  unmatched <- setdiff(refs, ids)
  if (length(unmatched)) stop("HTML references cid: ", paste(unmatched, collapse = ", "),
                              " with no matching inline image.", call. = FALSE)
  unused <- setdiff(ids, refs)
  if (length(unused)) warning("Inline image(s) not referenced in the HTML: ",
                              paste(unused, collapse = ", "), call. = FALSE)
  invisible(NULL)
}


#' The Content-IDs an HTML body references (internal)
#'
#' @param html The HTML body.
#' @return Character vector of Content-IDs, in order, possibly repeated.
#' @noRd
cid_refs <- function(html) {
  cid_walk(html)$refs
}


#' Walk every cid: reference a client draws, optionally rewriting it (internal)
#'
#' The one reader of `cid:` references, shared by the send-side check and the
#' preview so the two cannot disagree: a `src` or `background` attribute whose
#' value is `cid:<id>`, or a CSS `url(cid:<id>)` in a `style` attribute, read
#' from start tags only.
#'
#' @param html The HTML body.
#' @param replace `NULL`, or a function of one Content-ID returning the text
#'   to put in place of `cid:<id>`, or `NA` to leave it.
#' @return List: `refs`, the Content-IDs in order; `html`, rewritten.
#' @noRd
cid_walk <- function(html, replace = NULL) {
  tok <- "[A-Za-z0-9._@-]+"
  refs <- character()
  swap <- function(id, whole) {
    refs <<- c(refs, id)
    if (is.null(replace)) return(whole)
    r <- replace(id)
    if (is.na(r)) whole else r
  }
  html <- rewrite_start_tags(html, function(t, name) {
    a <- tag_attrs(t)
    # Right to left, so earlier positions stay valid as values change length
    for (i in rev(which(a$name %in% c("src", "background", "style")))) {
      v <- a$value[i]
      if (a$name[i] == "style") {
        mm <- gregexpr(paste0("(?i)(url\\(\\s*[\"']?)cid:(", tok, ")"), v, perl = TRUE)
        regmatches(v, mm) <- lapply(regmatches(v, mm), function(x) {
          vapply(x, function(u) {
            id <- sub(paste0("(?i)^url\\(\\s*[\"']?cid:(", tok, ")$"), "\\1", u, perl = TRUE)
            paste0(sub("(?i)cid:.*$", "", u, perl = TRUE), swap(id, paste0("cid:", id)))
          }, character(1), USE.NAMES = FALSE)
        })
      } else {
        hit <- regmatches(v, regexec(paste0("(?i)^(\\s*)cid:(", tok, ")(.*)$"), v, perl = TRUE))[[1]]
        if (length(hit) == 0) next
        v <- paste0(hit[2], swap(hit[3], paste0("cid:", hit[3])), hit[4])
      }
      if (identical(v, a$value[i])) next
      t <- paste0(substr(t, 1, a$vstart[i] - 1), a$quote[i], v, a$quote[i],
                  substr(t, a$vstart[i] + a$vlen[i], nchar(t)))
    }
    t
  })
  list(refs = refs, html = html)
}
