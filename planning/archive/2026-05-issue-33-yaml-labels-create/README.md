# 2026-05 — Issue #33: Auto-create missing Gmail labels for YAML-driven workflow

## Outcome

Closed the YAML "tag-as-you-go" friction surfaced in compost on 2026-05-05 (Upper Fraser draft needed manual `gmailr::gm_create_label("upper fraser")` before `mc_md_send` would apply the label). Three layered additions: `mc_label_ensure(label_names)` primitive, `mc_thread_modify(create_missing = FALSE)` opt-in flag, and `mc_send(labels_create = TRUE)` default-on so `mc_md_send` auto-creates new project tags on first use. Programmatic callers can pass `labels_create = FALSE` for strict typo-guard.

Code-check (4 rounds) caught two real bugs in round 1: (1) `names` arg in `mc_label_ensure` shadowed base `names()` — renamed to `label_names`; (2) `mc_label_ensure` skipped system labels case-insensitively but `resolve_label_names()` matched case-sensitively, leaving `add = "inbox"` with `create_missing = TRUE` in a broken state — fixed by making both consistent (`toupper(nm) %in% sys`) and normalizing returned IDs to uppercase. Side benefit: callers can now pass mixed-case system labels (`"Inbox"`, `"Starred"`) without erroring.

Tests: 8 new unit + 1 new integration. Full suite 302 PASS / 0 FAIL / 0 WARN (was 281 baseline at v0.2.8). Lint clean.

Closed by PR #34 (squash commit `4a6cbab`). Released as v0.2.9.
