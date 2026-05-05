# Findings — Auto-create missing Gmail labels for YAML-driven workflow (#33)

## Issue context

`mc_thread_modify()` errors on unknown labels (`R/mc_thread_modify.R:146-152`). The YAML-driven label workflow added in #31 reads `labels:` from frontmatter and applies them via `mc_thread_modify()` — but only succeeds if the labels already exist in Gmail.

When a user adds a new project tag to a draft (e.g. `labels: [upper fraser]`) and that label doesn't yet exist, `mc_md_send()` creates the draft, then the labels block fails. Per the v0.2.8 try-catch we land a warning (good — the draft survives), but the user still has to drop down to `gmailr::gm_create_label()` manually, then re-apply with `mc_thread_modify()`.

That's friction in the spot the YAML workflow was supposed to remove. Real-world workflow today:

```r
# Step 1: pre-create label via gmailr (mc has no helper)
gmailr::gm_create_label("upper fraser")

# Step 2: now mc_md_send works
mc_md_send("draft.md")  # YAML has labels: [upper fraser]
```

The whole point of YAML-driven labels is "tag as you go." Pre-creating breaks that.

Hit this in real use during the 2026-05-05 Brandon / Upper Fraser draft (had to manually pre-create the `upper fraser` label).

## Plan-mode exploration (2026-05-05)

### Code paths

- **`mc_thread_modify()`** (`R/mc_thread_modify.R:45-64`) — public; validates inputs, fetches user labels, resolves names to IDs, POSTs modify request. Errors on unknown labels via `resolve_label_names()` (lines 124-154).
- **`fetch_user_labels()`** (`R/mc_thread_modify.R:102-110`) — internal, returns `name -> id` named char vector. No caching across calls. Reusable.
- **`system_labels()`** (`R/mc_thread_modify.R:94-97`) — fixed list of 9 system labels (DRAFT, INBOX, STARRED, etc.). Reusable for skipping in `mc_label_ensure`.
- **`mc_send()` labels block** (`R/mc_send.R:306-339`) — applies labels via `mc_thread_modify()` inside `tryCatch` that downgrades errors to warnings.
- **`mc_md_send()`** — dispatches to `mc_send()` via `do.call`. New `mc_send()` args inherit automatically.

### Test patterns

- `test-mc_thread_modify.R` — uses `local_mocked_bindings()` to stub `gmailr::gm_labels()` and internal `gmail_modify_thread()`. System-label tests verify `gm_labels` is NOT called when all inputs are system labels.
- `test-mc_send.R` (lines 253-343) — mocks `mc_thread_modify()` directly to verify pass-through of labels arg.
- `test-mc_md_send.R` (lines 18-77) — stubs `mc_send()` to confirm YAML parsing.
- `test-integration.R` (lines 192-278) — live calls to `gmailr::gm_create_label()` for end-to-end label tests; gated by `MC_RUN_INTEGRATION=true`.

### Existing helpers / no conflicts

- No existing `mc_label_*` functions — clean slate for `mc_label_ensure()`.
- `gmailr` already in `Imports` (`DESCRIPTION:32`). `gm_create_label` not yet in NAMESPACE — `@importFrom` will add it.

### Conventions (from CLAUDE.md)

- One function per file → new `R/mc_label_ensure.R`.
- `lintr::lint_package()` + `devtools::test()` + `devtools::document()` before each commit.
- Version bump as final commit on branch.
- NEWS.md style: concise bullets, one feature per line, explain why not just what.
