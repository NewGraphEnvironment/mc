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
