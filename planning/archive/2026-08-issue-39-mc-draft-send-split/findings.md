# Findings — Split mc_send() into mc_draft() and mc_send() (#39)

## Issue context

## Problem

`mc_send()` drafts or sends depending on `draft`, a single boolean, so one character separates a reversible act from an irreversible one. The argument that reads as protective — `test` — is not: it only rewrites recipients (`to <- from`, cc/bcc/thread cleared), while `draft` alone selects `gm_create_draft()` vs `gm_send_message()`.

| `draft` | `test` | Result |
|---|---|---|
| `TRUE` | `FALSE` | Draft, real recipients |
| `TRUE` | `TRUE` | Draft, to self |
| `FALSE` | `TRUE` | **Sends**, to self only |
| `FALSE` | `FALSE` | **Sends to real recipients** |

On 2026-08-26 an enquiry went to nine external recipients when a draft was intended. Email cannot be recalled.

## Proposed Solution

Put the verb in the function name, so sending must be named rather than configured.

```r
mc_draft(...)      mc_md_draft(path)   # can only draft
mc_send(...)       mc_md_send(path)    # can only send
```

Drop `draft` entirely. Rename `test` to `to_self` — it describes what it does, and `mc_send(to_self = TRUE)` reads honestly.

No deprecated `draft =` alias; a path still accepting the flag preserves the ambiguity being removed.

## Migration risk

All 35+ compost call sites pass `draft` explicitly and will error loudly on the unused argument — none silently invert. The residual risk is a future bare `mc_md_send(path)` written from habit, which used to draft and would now send. Accepted: callers reach for `mc_draft()` in almost all cases, so the habit that forms is the safe one.

## Scope

- `R/mc_send.R`, `R/mc_md_send.R` — split; `send_at`/`scheduler` are send-only and stay on `mc_send()`
- Tests, `@examples`, README, vignettes
- Downstream compost sweep: `draft <- TRUE` → `mc_draft()`; 8 historical scripts on `draft <- FALSE` go inert, removing a live tripwire
- Breaking; bump to 0.3.0



## Exploration (2026-08-27)

Blast radius is narrower than a raw grep suggests. `draft` in
`R/mc_thread_find.R`, `R/mc_message_find.R` and `R/mc_preview.R` is a
**different concept** — Gmail draft *status* and `.md` draft *files*. Untouched.

Real scope: `R/mc_send.R`, `R/mc_md_send.R`, their tests,
`test-integration.R`, `README.md`, `CLAUDE.md`, `NEWS.md`, `DESCRIPTION`.

### Two things the issue did not anticipate

- **`override` can smuggle the flag back in.** `mc_md_send(override = list(draft = FALSE))`
  is a documented path (`R/mc_md_send.R:29-32`), tested at
  `test-mc_md_send.R:97`. Removing the formal argument is not enough; the
  `override` list needs its own guard.
- **mc's own `CLAUDE.md` BCC convention** is phrased in terms of `test = FALSE` /
  `test = TRUE`. Left alone it would contradict the new API.

### Confirmed

`send_at` already forces `draft = FALSE` in `schedule_args` (`R/mc_send.R:250`),
so scheduling is inherently a send — `send_at` / `scheduler` belong on
`mc_send()` only, and `mc_draft()` should reject them.
