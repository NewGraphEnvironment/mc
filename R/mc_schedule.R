#' Dispatch a scheduled send to the appropriate backend
#'
#' Internal dispatcher for [mc_send()]'s `send_at` path. Routes the
#' scheduled-send request to a backend implementation based on `scheduler`.
#'
#' @param target_time POSIXct fire time.
#' @param args Named list of `mc_send()` arguments to invoke at fire time.
#'   Excludes `send_at` (which is always `NULL` for the recursive call) and
#'   `path` (HTML body is pre-rendered into `args$html`).
#' @param scheduler One of `"callr"`, `"auto"`, `"launchd"`, `"at"`.
#'
#' @return A backend-specific handle. For `"callr"`, a callr process handle
#'   with `$is_alive()` and `$kill()` methods. For `"launchd"` / `"at"`, a
#'   list with `$backend`, `$label`, `$plist` (launchd), and `$args_path`.
#'
#' @noRd
schedule_send <- function(target_time, args, scheduler = "callr") {
  scheduler <- resolve_scheduler(scheduler)
  switch(scheduler,
    callr = schedule_callr(target_time, args),
    launchd = schedule_launchd(target_time, args),
    at = schedule_at(target_time, args),
    stop("Unknown scheduler: ", scheduler, call. = FALSE)
  )
}


#' Resolve `"auto"` scheduler to the OS-native backend
#'
#' On Darwin returns `"launchd"`. On Linux returns `"at"`. Errors with a
#' helpful message on other platforms.
#'
#' @noRd
resolve_scheduler <- function(scheduler) {
  if (scheduler != "auto") return(scheduler)
  sys <- Sys.info()[["sysname"]]
  switch(sys,
    Darwin = "launchd",
    Linux = "at",
    stop(
      "scheduler 'auto' not supported on ", sys,
      "; use scheduler = 'callr' explicitly until OS-native backends ",
      "land on this platform.",
      call. = FALSE
    )
  )
}


#' callr-based scheduler (existing default)
#'
#' Spawns a `callr::r_bg` child that sleeps until `target_time` then invokes
#' [mc_send()] via the recursive path. Caffeinate keeps the machine awake on
#' macOS. Lifecycle caveat (mc#36): the bg process can be cleaned up if its
#' parent context exits — `STARTED` log entry never lands, send drops silently.
#'
#' @noRd
schedule_callr <- function(target_time, args) {
  if (!requireNamespace("callr", quietly = TRUE)) {
    stop(
      "The callr package is required for scheduler = 'callr'. ",
      "Install with pak::pak('callr').",
      call. = FALSE
    )
  }
  proc <- callr::r_bg(
    function(target_time, grace_secs, args) {
      delay <- as.numeric(difftime(target_time, Sys.time(), units = "secs"))
      if (delay > 0) Sys.sleep(delay)
      late <- as.numeric(difftime(Sys.time(), target_time, units = "secs"))
      if (late > grace_secs) {
        msg <- paste0(
          "Scheduled send SKIPPED. Machine woke ",
          round(late / 60, 1), " min past target time ",
          format(target_time, "%H:%M:%S"),
          ". Draft not sent to protect against stale context."
        )
        mc:::send_log(args$subject, args$to, "SKIPPED", msg)
        mc:::send_notify(paste0("SKIPPED: ", args$subject), msg)
        stop(msg, call. = FALSE)
      }
      mc:::send_log(args$subject, args$to, "STARTED")
      tryCatch(
        {
          do.call(mc::mc_send, c(args, list(send_at = NULL)))
          mc:::send_log(args$subject, args$to, "SENT")
          mc:::send_notify(
            paste0("Sent: ", args$subject),
            paste0("To: ", paste(args$to, collapse = ", "))
          )
        },
        error = function(e) {
          mc:::send_log(args$subject, args$to, "FAILED", conditionMessage(e))
          mc:::send_notify(
            paste0("FAILED: ", args$subject),
            conditionMessage(e)
          )
          stop(e)
        }
      )
    },
    args = list(target_time = target_time, grace_secs = 300, args = args),
    package = "mc"
  )
  caffeinate_send(proc)
  invisible(proc)
}


#' Schedule a one-shot send via macOS launchd
#'
#' Serializes `args` to JSON, writes a launchd plist with `StartCalendarInterval`
#' set to `target_time`, loads the plist via `launchctl load -w`. At fire time,
#' launchd invokes `Rscript -e 'mc:::run_scheduled_send("<args.json>")'`. The
#' fire-time helper logs heartbeats, runs the send, and cleans up the plist
#' and args JSON regardless of outcome.
#'
#' @noRd
schedule_launchd <- function(target_time, args) {
  uuid <- generate_send_uuid()
  scheduled_dir <- file.path(Sys.getenv("HOME"), ".mc", "scheduled")
  if (!dir.exists(scheduled_dir)) dir.create(scheduled_dir, recursive = TRUE)

  args_path <- file.path(scheduled_dir, paste0(uuid, ".json"))
  jsonlite::write_json(args, args_path, auto_unbox = TRUE, null = "null")

  label <- paste0("com.newgraph.mc.send-", uuid)
  agents_dir <- file.path(Sys.getenv("HOME"), "Library", "LaunchAgents")
  if (!dir.exists(agents_dir)) dir.create(agents_dir, recursive = TRUE)
  plist_path <- file.path(agents_dir, paste0(label, ".plist"))

  rscript <- Sys.which("Rscript")
  if (rscript == "") {
    stop("Rscript not found on PATH — required by launchd backend.",
         call. = FALSE)
  }

  plist_xml <- launchd_plist(label, target_time, rscript, args_path,
                             scheduled_dir)
  writeLines(plist_xml, plist_path)

  res <- system2(
    "launchctl", c("load", "-w", plist_path),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(res, "status")
  if (!is.null(status) && status != 0) {
    unlink(c(plist_path, args_path))
    stop("launchctl load failed: ", paste(res, collapse = " "),
         call. = FALSE)
  }

  invisible(list(
    backend = "launchd",
    label = label,
    plist = plist_path,
    args_path = args_path
  ))
}


#' Build a one-shot launchd plist XML for a scheduled send
#'
#' `StartCalendarInterval` triggers the job at the matching minute; the job
#' self-unloads at end of [run_scheduled_send()] so it never re-fires.
#'
#' @noRd
launchd_plist <- function(label, target_time, rscript_path, args_json_path,
                          scheduled_dir) {
  tt <- as.POSIXlt(target_time)
  out_log <- file.path(scheduled_dir, paste0(label, ".out"))
  err_log <- file.path(scheduled_dir, paste0(label, ".err"))

  paste(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    '<plist version="1.0">',
    '<dict>',
    paste0("  <key>Label</key><string>", label, "</string>"),
    "  <key>ProgramArguments</key>",
    "  <array>",
    paste0("    <string>", rscript_path, "</string>"),
    "    <string>-e</string>",
    paste0("    <string>mc:::run_scheduled_send(\"",
           args_json_path, "\")</string>"),
    "  </array>",
    "  <key>StartCalendarInterval</key>",
    "  <dict>",
    paste0("    <key>Year</key><integer>", tt$year + 1900, "</integer>"),
    paste0("    <key>Month</key><integer>", tt$mon + 1, "</integer>"),
    paste0("    <key>Day</key><integer>", tt$mday, "</integer>"),
    paste0("    <key>Hour</key><integer>", tt$hour, "</integer>"),
    paste0("    <key>Minute</key><integer>", tt$min, "</integer>"),
    "  </dict>",
    "  <key>RunAtLoad</key><false/>",
    paste0("  <key>StandardOutPath</key><string>", out_log, "</string>"),
    paste0("  <key>StandardErrorPath</key><string>", err_log, "</string>"),
    "</dict>",
    "</plist>",
    sep = "\n"
  )
}


#' Schedule a one-shot send via Linux `at`
#'
#' Serializes `args` to JSON, pipes a one-line `Rscript -e ...` invocation
#' into `at -t YYYYMMDDhhmm.ss`. The `atd` daemon owns the job lifecycle —
#' it survives shell exit, parent process death, and (on systemd hosts)
#' the originating R session disappearing entirely.
#'
#' Assumes `atd` is running. On most Linux distros (Ubuntu/Debian VMs in
#' our fleet) it's default-enabled. If `atd` is stopped, `at` will accept
#' and queue the job but it will never fire — a silent failure mode worth
#' watching for. Verify with `systemctl is-active atd` or equivalent.
#'
#' @noRd
schedule_at <- function(target_time, args) {
  uuid <- generate_send_uuid()
  scheduled_dir <- file.path(Sys.getenv("HOME"), ".mc", "scheduled")
  if (!dir.exists(scheduled_dir)) dir.create(scheduled_dir, recursive = TRUE)

  args_path <- file.path(scheduled_dir, paste0(uuid, ".json"))
  jsonlite::write_json(args, args_path, auto_unbox = TRUE, null = "null")

  rscript <- Sys.which("Rscript")
  if (rscript == "") {
    stop("Rscript not found on PATH — required by at backend.",
         call. = FALSE)
  }

  # at -t accepts: [[CC]YY]MMDDhhmm[.ss]
  at_time <- format(target_time, "%Y%m%d%H%M.%S")

  # Body of the at job — single Rscript invocation that reads the args
  # JSON and runs the send. The args path is written by us above, so
  # quoting safety is bounded to package-generated uuid filenames.
  job_cmd <- sprintf(
    "%s -e 'mc:::run_scheduled_send(\"%s\")'",
    rscript, args_path
  )

  res <- system2(
    "at", c("-t", at_time),
    input = job_cmd,
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(res, "status")
  if (!is.null(status) && status != 0) {
    unlink(args_path)
    stop("at command failed: ", paste(res, collapse = " "),
         call. = FALSE)
  }

  # `at` typically prints "job N at <time>" to stderr; capture the job
  # number for diagnostic logging if available.
  job_id <- NA_character_
  job_match <- grep("^job [0-9]+", res, value = TRUE)
  if (length(job_match) > 0) {
    m <- regmatches(job_match[1], regexpr("^job [0-9]+", job_match[1]))
    if (length(m) > 0) job_id <- sub("^job ", "", m)
  }

  invisible(list(
    backend = "at",
    job_id = job_id,
    args_path = args_path
  ))
}


#' Fire-time entry point for OS-native scheduled sends
#'
#' Reads serialized args, invokes [mc_send()], logs heartbeats, and cleans up
#' the plist + args JSON whether the send succeeded or failed.
#'
#' @param args_json_path Path to the JSON file written by the backend at
#'   schedule time (e.g. `~/.mc/scheduled/<uuid>.json`).
#'
#' @return Invisibly `NULL`. Side effects: log entries, `mc_send()` call,
#'   cleanup of scheduling artifacts.
#'
#' @keywords internal
run_scheduled_send <- function(args_json_path) {
  args <- jsonlite::read_json(args_json_path, simplifyVector = TRUE)
  on.exit(cleanup_scheduled_send(args_json_path), add = TRUE)

  send_log(args$subject, args$to, "STARTED")

  tryCatch(
    {
      do.call(mc_send, c(args, list(send_at = NULL)))
      send_log(args$subject, args$to, "SENT")
      send_notify(
        paste0("Sent: ", args$subject),
        paste0("To: ", paste(args$to, collapse = ", "))
      )
    },
    error = function(e) {
      send_log(args$subject, args$to, "FAILED", conditionMessage(e))
      send_notify(paste0("FAILED: ", args$subject), conditionMessage(e))
      stop(e)
    }
  )
  invisible(NULL)
}


#' Cleanup launchd plist + args JSON after a scheduled send completes
#'
#' Idempotent — safe to call multiple times. Unlinks all scheduling artifacts
#' (plist, args JSON, captured stdout/stderr).
#'
#' @section macOS lifecycle note:
#' We deliberately do NOT call `launchctl unload` from inside the running
#' job. `unload` sends SIGTERM to the entire job process group, killing
#' this R process before any subsequent unlink calls run — leaving the
#' plist + args JSON + log files on disk forever (real failure observed
#' in a live test on 2026-05-08). Instead we just unlink the plist file
#' directly. launchd's in-memory job registry retains the entry as
#' "exited 0" until next reboot or manual `launchctl bootout`. Because
#' our `StartCalendarInterval` targets a single past minute, the dormant
#' entry never re-fires. The only visible cost is `launchctl list`
#' accumulating stale entries until reboot — purely cosmetic.
#'
#' @noRd
cleanup_scheduled_send <- function(args_json_path) {
  uuid <- sub("\\.json$", "", basename(args_json_path))
  label <- paste0("com.newgraph.mc.send-", uuid)
  scheduled_dir <- dirname(args_json_path)

  # Args JSON cleanup — unconditional across platforms
  unlink(args_json_path)

  if (Sys.info()[["sysname"]] == "Darwin") {
    plist_path <- file.path(Sys.getenv("HOME"), "Library", "LaunchAgents",
                            paste0(label, ".plist"))
    unlink(plist_path)
    unlink(file.path(scheduled_dir, paste0(label, c(".out", ".err"))))
  }

  invisible(NULL)
}


#' Generate a unique-ish identifier for a scheduled send
#'
#' Combines a timestamp prefix with random suffix for sortability and
#' uniqueness. Not cryptographically random — collision risk is negligible
#' for the intended use (one user's scheduled sends, sub-second uniqueness).
#'
#' @noRd
generate_send_uuid <- function() {
  paste0(
    format(Sys.time(), "%Y%m%d%H%M%S"), "-",
    paste(sample(c(0:9, letters), 8, replace = TRUE), collapse = "")
  )
}
