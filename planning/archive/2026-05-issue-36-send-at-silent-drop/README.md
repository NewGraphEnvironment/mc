# 2026-05 — Issue #36: Scheduled send (`send_at`) silently dropped

## Outcome

Closed the silent-drop bug from 2026-05-07 where a `mc_md_send(..., send_at = 15)` call vanished — no log entry, no notification, no fire. Root cause: `callr::r_bg` child got cleaned up when its parent `Rscript -e` invocation exited. Fix shipped in two halves: heartbeat logging (`SCHEDULED` at submission, `STARTED` at fire) so missed fires are auditable, and OS-native scheduling backends (`scheduler = "auto"` selects `launchd` on macOS, `at` on Linux) that own their lifecycle independent of any R session. Default `scheduler = "callr"` now warns to steer users toward the durable path.

Code-check (4 rounds across phases) caught 2 real issues plus a third surfaced by **live testing** on macOS — the launchd path fired correctly but `cleanup_scheduled_send` was calling `launchctl unload` from inside the running job, which SIGTERMs the job's process group and killed the cleanup mid-flight. Fix: drop the unload call entirely, just unlink the files. `launchctl list` shows a stale "exited 0" entry until next reboot but the dormant `StartCalendarInterval` (single past minute) never re-fires. Documented the lifecycle reasoning in the cleanup function so future maintainers don't reintroduce the unload call.

Tests: 17 new test_that blocks split between `test-mc_send.R` and the new `test-mc_schedule.R`. Suite went from 302 (v0.2.9 baseline) to 365 PASS. Live test on a real Gmail send confirmed end-to-end behavior: scheduled at 12:46:42, originating Rscript exited immediately, launchd fired at 12:52:42, email landed in inbox.

Closed by PR #37 (squash commit `dfff36e`). Released as v0.2.10. Also exercised the new `/gh-pr-merge` SKIP_BUMP path (added to soul yesterday) for the first time — correctly tagged at the merge SHA without phantom-bumping.
