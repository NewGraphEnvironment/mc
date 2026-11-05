# Progress — [1/3] Run mc unattended (#47)

## Session 2026-11-04

- Plan-mode exploration — phases approved by user
- Created branch `47-1-3-run-mc-unattended-r-cmd-check-in-ci` off origin/main
- Scaffolded PWF baseline from issue #47 with approved phases
- Next: start Phase 1
- Phase 1: merged `origin/ci-r-cmd-check` (PR #46's workflow) and kept `.lintr`/`.claude` out of the tarball
- Phase 2: the three tests went red with the sender unset and `gm_labels` mocked to stop, then green with the path/html check moved first and `toupper()` in `mc_thread_modify()`
- Phase 3: six string-literal em dashes made ASCII (`.check_package_ASCII_code` now empty, no test matched those messages); `...` documented in `mc_draft()`, `checkDocFiles` clean
- Phase 4: four scheduler-default tests (macOS and Linux red before the change; the Windows fallback and explicit-`auto` error already held); `scheduler = NULL` resolved by `default_scheduler()`; the two callr-warning tests now name `scheduler = "callr"`; README, `@param` and CLAUDE.md updated
- Phase 5: `mc_auth_check()` with 9 tests on fake tokens in a temp cache; four planted defects (always pass, email suffix without `_`, `$client` only, option handling dropped) each turned a test red. `rappdirs` added to Imports beside `gargle`. README Troubleshooting section.
- Plan review landed after Phases 1–5 (`review-plan.md`): findings 3–9 taken (client-id filter and scope caveat in `mc_auth_check()`, a test that could really send now mocks `gm_send_message`, vignette and callr warning updated for the new default, `schedule_at()` names the fix when `at` is missing), 1–2 were already in the code and gained tests; each new guard went red with its defect planted in a scratch copy
- `/code-check branch` round 1 (`review-round1.md`): 3 findings, all fixed. `mc_auth_check()` matched emails by suffix (`sales_al@` passed for `al@`), now exact. The OS-native backends had no stale-send guard (launchd and atd run a missed job at wake), so the args JSON carries the target time and grace and `run_scheduled_send()` skips and logs `SKIPPED` past 300 s, as callr does. `schedule_at()` warns when `pgrep` finds no atd. Each fix went red with its defect planted.
- `/code-check branch` round 2 (`review-round2.md`): 3 findings. Fixed (inside round 1's fix): launchd and at took the fire time's digits in the target's own zone while the new guard compares instants, so a UTC `send_at` on a Pacific machine fired 8 h late and was skipped; both now take machine-local digits (`tz = ""`), and the old plist test that copied the defect expects local digits. Fixed: one writer `write_scheduled_args()` for both backends, tests go through it with an absolute tolerance. Accepted: an older installed mc reading the new JSON keys fails the send; only a `load_all()` session against an older install hits it. Probe note: this Mac's tzdata puts America/Vancouver on MST (UTC-7) in Nov 2026, so the zone test uses Asia/Tokyo.
