# Findings — Scheduled send (`send_at`) silently dropped (#36)

## Issue context

The 2026-05-07 NRP email scheduled via `mc_md_send(..., override = list(draft = FALSE, send_at = 15))` never sent. Silent failure: no entry in `~/.mc/send_log.txt`, no FAILED or SKIPPED notification, no warning. The drop was discovered the next morning when no reply had arrived.

Reproduction context:
- `mc_md_send` called from a one-shot `Rscript -e '...'` invocation
- mc spawned `callr::r_bg(...)` child with caffeinate watching its PID
- "Process alive: TRUE" reported at scheduling time
- Target fire time: 13:33:48
- Outcome: no fire, no log, no R or caffeinate process running by next session

Root-cause hypothesis: `callr::r_bg` child cleaned up when parent `Rscript` exited. Detached child inherits a process group that gets SIGHUP'd when the controlling shell session ends. When the child dies, caffeinate (`-w <pid>`) exits cleanly because its watched PID is gone — both processes vanish without trace.

## Plan-mode exploration (2026-05-08)

### Code paths in `R/mc_send.R`

- **`send_at` block** (lines 175–248) — the scheduled-send guard. Captures all args into a `callr::r_bg` closure, sets up `Sys.sleep(delay)`, missed-window grace check (300s default), and recursive `mc::mc_send` call after the sleep. Logs SENT/SKIPPED/FAILED via `send_log()`. Caffeinate spawned via `caffeinate_send(proc)` immediately after `r_bg` setup.
- **`send_log()`** (lines 392–403) — internal helper. Writes one line per event to `~/.mc/send_log.txt` in format `YYYY-MM-DD HH:MM:SS | STATUS | To: addrs | Subject: text | [optional detail]`. Already accepts arbitrary status string — extending to `SCHEDULED` / `STARTED` is purely additive.
- **`send_notify()`** (lines 412–423) — macOS-only `osascript` notification. Silently no-ops on non-Darwin.
- **`caffeinate_send()`** (lines 374–381) — `system2("caffeinate", c("-i", "-w", pid), wait = FALSE, ...)`. macOS-only guard.
- **`resolve_send_at()`** (lines 430–445) — validates POSIXct-or-numeric input, returns POSIXct target. Used as-is by future backends.

### Existing tests

- `tests/testthat/test-mc_send.R` lines 8–35: `resolve_send_at` validation tests (5 expectations).
- Lines 157–172: `send_log` and `send_notify` unit tests.
- Line 360: `caffeinate is not called when send_at is NULL` — mocks `caffeinate_send`.
- **Gap:** no integration tests that actually fire a scheduled send. The `callr::r_bg` background-process logic itself is never tested. Designing the new backends with strong unit-level mock tests is the right call; integration tests can be gated by env var like `test-integration.R`.

### Dependencies + conventions

- `callr` is in `Suggests` (DESCRIPTION line 19), not Imports. Code guards with `requireNamespace("callr", quietly = TRUE)`.
- No existing `lifecycle` package usage. Mc convention is plain `warning(call. = FALSE)` — going with that for the deprecation warning.
- `system2` already used in mc_send.R for `caffeinate` (line 377) and `osascript` (line 419). Pattern is known.
- No existing `launchd` / `launchctl` / `at` references anywhere in the repo. New territory.
- `jsonlite` already in Imports — confirmed available for args serialization.

### NEWS history

`send_at` shipped in mc 0.1.0 with one bullet: *"Scheduled send with `send_at` and macOS `caffeinate` integration."* No subsequent updates. Bug surfaced 2026-05-07 — single failure mode, but high-severity since it's silent.

### CLAUDE.md

No specific deprecation guidance in mc CLAUDE.md. Use plain `warning()` for user-facing messages, no `lifecycle` dep needed.
