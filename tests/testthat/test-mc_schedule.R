test_that("resolve_scheduler passes through non-auto values", {
  expect_equal(mc:::resolve_scheduler("callr"), "callr")
  expect_equal(mc:::resolve_scheduler("launchd"), "launchd")
  expect_equal(mc:::resolve_scheduler("at"), "at")
})

test_that("resolve_scheduler maps auto to launchd on Darwin", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Darwin"),
    .package = "base"
  )
  expect_equal(mc:::resolve_scheduler("auto"), "launchd")
})

test_that("resolve_scheduler maps auto to at on Linux", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    .package = "base"
  )
  expect_equal(mc:::resolve_scheduler("auto"), "at")
})

test_that("resolve_scheduler errors on auto for unsupported platform", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Windows"),
    .package = "base"
  )
  expect_error(
    mc:::resolve_scheduler("auto"),
    "scheduler 'auto' not supported on Windows"
  )
})

test_that("schedule_at writes args JSON and pipes Rscript invocation to at", {
  at_calls <- list()
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      kwargs <- list(...)
      at_calls[[length(at_calls) + 1]] <<-
        list(command = command, args = args, input = kwargs$input)
      "job 42 at Sat May 10 14:30:00 2026"
    },
    .package = "base"
  )

  tmp_home <- tempfile("mc-test-home-")
  dir.create(tmp_home)
  withr::local_envvar(HOME = tmp_home)
  withr::defer(unlink(tmp_home, recursive = TRUE))

  target <- as.POSIXct("2026-05-10 14:30:00", tz = "")
  args <- list(
    to = "test@test.com", subject = "at test",
    from = "from@test.com", html = "<p>x</p>"
  )

  handle <- mc:::schedule_at(target, args)

  # Handle shape
  expect_equal(handle$backend, "at")
  expect_equal(handle$job_id, "42")
  expect_true(file.exists(handle$args_path))

  # Args JSON round-trip
  read_back <- jsonlite::read_json(handle$args_path, simplifyVector = TRUE)
  expect_equal(read_back$to, "test@test.com")
  expect_equal(read_back$subject, "at test")

  # at invoked with -t YYYYMMDDhhmm.ss + Rscript invocation as stdin
  at_call <- at_calls[[length(at_calls)]]
  expect_equal(at_call$command, "at")
  expect_equal(at_call$args[1], "-t")
  expect_match(at_call$args[2], "^20260510[0-9]{4}\\.[0-9]{2}$")
  expect_match(at_call$input, "run_scheduled_send", fixed = TRUE)
  expect_match(at_call$input, handle$args_path, fixed = TRUE)
})

test_that("schedule_at unlinks args JSON and stops on at command failure", {
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      result <- "at: bad time specification"
      attr(result, "status") <- 1L
      result
    },
    .package = "base"
  )

  tmp_home <- tempfile("mc-test-home-")
  dir.create(tmp_home)
  withr::local_envvar(HOME = tmp_home)
  withr::defer(unlink(tmp_home, recursive = TRUE))

  expect_error(
    mc:::schedule_at(
      as.POSIXct("2026-05-10 14:30:00"),
      list(to = "x@x.com", subject = "x", from = "f@f.com",
           html = "<p>x</p>")
    ),
    "at command failed"
  )

  # No leftover args JSON in the scheduled dir
  scheduled_dir <- file.path(tmp_home, ".mc", "scheduled")
  if (dir.exists(scheduled_dir)) {
    leftovers <- list.files(scheduled_dir, pattern = "\\.json$")
    expect_equal(length(leftovers), 0L)
  }
})

test_that("launchd_plist embeds target time + ProgramArguments correctly", {
  target <- as.POSIXct("2026-12-25 14:30:00", tz = "UTC")
  xml <- mc:::launchd_plist(
    label = "com.newgraph.mc.send-test",
    target_time = target,
    rscript_path = "/usr/local/bin/Rscript",
    args_json_path = "/tmp/test-args.json",
    scheduled_dir = "/tmp/scheduled"
  )

  # Plist structure
  expect_match(xml, '<?xml version="1.0"', fixed = TRUE)
  expect_match(xml, '<plist version="1.0">', fixed = TRUE)
  expect_match(xml, "<key>Label</key><string>com.newgraph.mc.send-test</string>",
               fixed = TRUE)

  # ProgramArguments — Rscript path + -e + run_scheduled_send invocation
  expect_match(xml, "<string>/usr/local/bin/Rscript</string>", fixed = TRUE)
  expect_match(xml, "<string>-e</string>", fixed = TRUE)
  expect_match(xml, 'run_scheduled_send(\"/tmp/test-args.json\")', fixed = TRUE)

  # StartCalendarInterval — local time decomposition matches target
  tt <- as.POSIXlt(target)
  yr <- paste0("<key>Year</key><integer>", tt$year + 1900, "</integer>")
  mo <- paste0("<key>Month</key><integer>", tt$mon + 1, "</integer>")
  dy <- paste0("<key>Day</key><integer>", tt$mday, "</integer>")
  hr <- paste0("<key>Hour</key><integer>", tt$hour, "</integer>")
  mn <- paste0("<key>Minute</key><integer>", tt$min, "</integer>")
  expect_match(xml, yr, fixed = TRUE)
  expect_match(xml, mo, fixed = TRUE)
  expect_match(xml, dy, fixed = TRUE)
  expect_match(xml, hr, fixed = TRUE)
  expect_match(xml, mn, fixed = TRUE)

  # RunAtLoad false — only fires at calendar interval
  expect_match(xml, "<key>RunAtLoad</key><false/>", fixed = TRUE)
})

test_that("schedule_launchd writes plist + args JSON and loads via launchctl", {
  skip_on_os(c("windows", "linux", "solaris"))

  launchctl_calls <- list()
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      launchctl_calls[[length(launchctl_calls) + 1]] <<-
        list(command = command, args = args)
      ""
    },
    .package = "base"
  )

  tmp_home <- tempfile("mc-test-home-")
  dir.create(tmp_home)
  withr::local_envvar(HOME = tmp_home)
  withr::defer(unlink(tmp_home, recursive = TRUE))

  target <- Sys.time() + 60
  args <- list(
    to = "test@test.com", subject = "test subject",
    from = "from@test.com", html = "<p>x</p>"
  )

  handle <- mc:::schedule_launchd(target, args)

  # Handle shape
  expect_equal(handle$backend, "launchd")
  expect_match(handle$label, "^com\\.newgraph\\.mc\\.send-")
  expect_true(file.exists(handle$plist))
  expect_true(file.exists(handle$args_path))

  # Args JSON round-trip
  read_back <- jsonlite::read_json(handle$args_path, simplifyVector = TRUE)
  expect_equal(read_back$to, "test@test.com")
  expect_equal(read_back$subject, "test subject")

  # launchctl invoked with load -w <plist>
  load_call <- launchctl_calls[[length(launchctl_calls)]]
  expect_equal(load_call$command, "launchctl")
  expect_equal(load_call$args[1:2], c("load", "-w"))
  expect_equal(load_call$args[3], handle$plist)
})

test_that("run_scheduled_send round-trips args, logs heartbeats, cleans up", {
  send_calls <- list()
  log_calls <- list()
  notify_calls <- list()

  local_mocked_bindings(
    mc_send = function(...) {
      send_calls[[length(send_calls) + 1]] <<- list(...)
      "thread_id_xyz"
    },
    send_log = function(subject, to, status, detail = "") {
      log_calls[[length(log_calls) + 1]] <<-
        list(subject = subject, to = to, status = status, detail = detail)
    },
    send_notify = function(title, body) {
      notify_calls[[length(notify_calls) + 1]] <<-
        list(title = title, body = body)
    },
    cleanup_scheduled_send = function(args_json_path) {
      # Confirm cleanup is invoked; do nothing else for the test
      cleanup_invoked_with <<- args_json_path
    },
    .package = "mc"
  )
  cleanup_invoked_with <- NULL

  args_path <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(to = "rcpt@x.com", subject = "scheduled test",
         from = "from@x.com", html = "<p>body</p>"),
    args_path, auto_unbox = TRUE
  )
  withr::defer(unlink(args_path))

  mc:::run_scheduled_send(args_path)

  # mc_send was called with send_at = NULL
  expect_equal(length(send_calls), 1L)
  expect_null(send_calls[[1]]$send_at)
  expect_equal(send_calls[[1]]$to, "rcpt@x.com")
  expect_equal(send_calls[[1]]$subject, "scheduled test")

  # STARTED entry first, then SENT
  statuses <- vapply(log_calls, function(c) c$status, character(1))
  expect_equal(statuses, c("STARTED", "SENT"))

  # Notify fired with "Sent: <subject>"
  expect_equal(length(notify_calls), 1L)
  expect_equal(notify_calls[[1]]$title, "Sent: scheduled test")

  # Cleanup invoked with the args path
  expect_equal(cleanup_invoked_with, args_path)
})

test_that("run_scheduled_send logs FAILED on mc_send error", {
  log_calls <- list()
  notify_calls <- list()
  local_mocked_bindings(
    mc_send = function(...) stop("simulated failure"),
    send_log = function(subject, to, status, detail = "") {
      log_calls[[length(log_calls) + 1]] <<-
        list(status = status, detail = detail)
    },
    send_notify = function(title, body) {
      notify_calls[[length(notify_calls) + 1]] <<- list(title = title)
    },
    cleanup_scheduled_send = function(args_json_path) NULL,
    .package = "mc"
  )

  args_path <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(to = "x@x.com", subject = "fail test",
         from = "f@x.com", html = "<p>x</p>"),
    args_path, auto_unbox = TRUE
  )
  withr::defer(unlink(args_path))

  expect_error(mc:::run_scheduled_send(args_path), "simulated failure")

  statuses <- vapply(log_calls, function(c) c$status, character(1))
  expect_equal(statuses, c("STARTED", "FAILED"))
  expect_match(log_calls[[2]]$detail, "simulated failure")
  expect_equal(notify_calls[[1]]$title, "FAILED: fail test")
})

test_that("cleanup_scheduled_send is idempotent and removes args JSON", {
  args_path <- tempfile(fileext = ".json")
  writeLines("{}", args_path)

  expect_true(file.exists(args_path))
  mc:::cleanup_scheduled_send(args_path)
  expect_false(file.exists(args_path))

  # Idempotent — second call doesn't error
  expect_no_error(mc:::cleanup_scheduled_send(args_path))
})

test_that("cleanup_scheduled_send does NOT call launchctl unload", {
  # Regression: live test 2026-05-08 found that calling launchctl unload
  # from within the running launchd job sends SIGTERM to the job's
  # process group — kills R before any subsequent unlinks run, leaving
  # plist + args JSON + log files on disk. Fix: drop the unload call
  # entirely; just unlink the files. Stale launchctl list entry persists
  # until reboot but never re-fires.
  system2_calls <- list()
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      system2_calls[[length(system2_calls) + 1]] <<-
        list(command = command, args = args)
      ""
    },
    .package = "base"
  )

  args_path <- tempfile(fileext = ".json")
  writeLines("{}", args_path)
  withr::defer(unlink(args_path))

  mc:::cleanup_scheduled_send(args_path)

  launchctl_calls <- Filter(
    function(c) identical(c$command, "launchctl"),
    system2_calls
  )
  expect_equal(length(launchctl_calls), 0L)
})

test_that("mc_send rejects invalid scheduler value", {
  expect_error(
    mc_send(html = "<p>x</p>", to = "t@t.com", subject = "s",
            from = "f@f.com", send_at = 5, scheduler = "invalid"),
    "should be one of"
  )
})

test_that("mc_send pre-renders path-based markdown before scheduling", {
  # Regression for code-check round 1: path was previously dropped from
  # scheduled args, so a path-only call would render at fire time — but
  # html was NULL when args were serialized, leading to silent "Provide
  # either path or html" failure. Fix: render body_html before the
  # send_at dispatch so args carry pre-rendered html.
  schedule_args <- NULL
  local_mocked_bindings(
    schedule_send = function(target_time, args, scheduler) {
      schedule_args <<- args
      list(backend = "test", label = "test")
    },
    .package = "mc"
  )

  draft_path <- tempfile(fileext = ".md")
  writeLines(c(
    "---", "to: a@b.com", "subject: T", "---",
    "body content"
  ), draft_path)
  withr::defer(unlink(draft_path))

  suppressMessages(suppressWarnings(
    mc_send(
      path = draft_path,
      to = "a@b.com", subject = "T", from = "f@f.com",
      send_at = 5, scheduler = "callr"
    )
  ))

  expect_false(is.null(schedule_args$html),
               info = "html should be pre-rendered into args before scheduling")
  expect_match(schedule_args$html, "body content", fixed = TRUE)
})
