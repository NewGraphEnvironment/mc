# Progress — Split mc_send() into mc_draft() and mc_send() (#39)

## Session 2026-08-27

- Plan-mode exploration of `R/mc_send.R`, `R/mc_md_send.R`, tests, README
- Phases approved by user
- Created branch `39-split-mc-send-into-mc-draft-and-mc-send` off main
- Scaffolded PWF baseline from issue #39 with approved phases
- Next: Phase 1 — failing tests

### Phase 1 — tests first (complete)

- `test-mc_draft.R`, `test-mc_md_draft.R` new; `test-mc_send.R`, `test-mc_md_send.R` converted to send-only
- All fail with "could not find function mc_draft" — the contract is set
- Two guards encoded that the issue did not call for: `mc_draft()` rejects
  `send_at`/`scheduler`, and `override` rejects `draft`/`test` keys
