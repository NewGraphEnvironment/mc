# Progress — mc#31

## Session 2026-04-25

- Branch: `feature/issue-31-yaml-labels`
- Read source: `mc_send`, `mc_md_send`, `mc_thread_modify`, `mc_md_meta`, `test-mc_send.R`
- Wrote PWF baseline: `task_plan.md`, `findings.md`, `progress.md`
- Baseline commit: 6b09fbe (un-gitignored planning/active/, added baseline files)
- Phase 2 complete: mc_send captures threadId from gmailr response, returns invisibly. Added `extract_thread_id()` helper for both draft (nested under `$message`) and sent (top-level) shapes. Updated existing mocks + added 2 new tests (new-thread send, NULL when response lacks threadId). All 31 mc_send tests pass.
- Phase 3 complete: added `labels` arg to mc_send. Both draft and sent paths apply via mc_thread_modify(thread_id, add = labels) and message confirmation. Edge case: response without threadId + labels set → warning. Threaded labels through scheduled-send recursive call. Behavior change vs initial design: drafts get labelled too (user wants tags applied regardless of who sends or whether it gets finished). 4 new tests, all 40 pass.
- Next: Phase 4 (mc_md_send reads labels: from YAML)
