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

### Phase 2 — core split (complete)

- `R/mc_deliver.R` holds the shared implementation plus the existing file-local
  helpers; `R/mc_send.R` and `R/mc_draft.R` are thin wrappers fixing `.draft`
- `test` → `to_self` throughout; message text now "TO SELF: addressed to ..."
- `mc_draft()` takes `...` purely to reject `send_at`/`scheduler` with a message
  naming `mc_send()`, rather than an opaque unused-argument error
- 66 pass / 0 fail on the draft+send suites

### Phase 3 — frontmatter wrappers (complete)

- Frontmatter reading and argument assembly factored into internal
  `md_dispatch_args()`; `mc_md_draft()` and `mc_md_send()` differ only in which
  function they dispatch to
- `override` guards reject `draft` and `test` keys with messages naming the
  replacement, rather than an unused-argument error further down
- Full suite: 396 pass / 0 fail / 1 skip

### Phase 4 — docs, integration tests, release

- Integration tests: four `draft = FALSE, test = TRUE` sites became
  `mc_send(to_self = TRUE)`. Two others relied on the old `draft = TRUE`
  default and had to become `mc_draft()` — a blanket rename would have left
  them sending while asserting `in:drafts`
- README quick start now leads with `mc_draft()`; "Test mode" section renamed
  and reworded, since `to_self` caps recipients rather than preventing a send
- `CLAUDE.md` BCC convention rephrased off `test`
- NEWS 0.3.0 with a migration table
- 396 pass / 0 fail; lint clean in every file this branch touches (the 12
  remaining package lints are in files untouched here)
