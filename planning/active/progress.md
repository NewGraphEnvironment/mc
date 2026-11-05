# Progress — [2/3] Email body (#43)

## Session 2026-11-05

- Plan-mode exploration — phases approved by user
- Worked on the existing branch `43-inline-images` (gate decision 1), not a new branch; merged
  origin/main into it (67d97b8). One expected test failure, the Phase 1 defect (findings.md)
- Scaffolded PWF baseline from issue #43 with approved phases
- Next: Phase 1
- Phase 1: `write_scheduled_args()` writes `inline_images` as a JSON object; new
  `read_scheduled_args()` (used by `run_scheduled_send()` and by main's round-trip guard) turns
  it back into a named character vector; `mc_deliver()` makes each image's directory absolute,
  keeping names. Tests watched red first (4 in test-inline_images.R, the guard in test-mc_schedule.R)
- Phase 2: `check_inline_images()` reads only `src="cid:…"` / `src='cid:…'` (case-insensitive, spaces around `=`); prose test watched red first
- Phase 3: `inline_table_styles()` rewritten over a `style_tag()` helper, one match per tag (bare, attributes without style, existing style in either quote), idempotent; aligned commonmark cells now styled. Tests watched red first
- Phase 4: `inject_link_target()` adds `target="_blank"` and `rel="noopener noreferrer"` to each `<a href>`, keeping an existing target/rel; called from `mc_md_render()` and `mc_compose()`; roxygen of both updated. Tests watched red first
- Phase 5: two integration tests read the sent message back from Gmail (`mc_send(path =, sig = TRUE, inline_images =)` and `mc_md_send()` with frontmatter `inline_images:`). `MC_RUN_INTEGRATION=true devtools::test(filter = "integration")` 2026-11-05T07:05Z: 38 pass, 0 fail
- Phase 4b: plan-review follow-ups (cid scan forms, fragment links, quoted-value attribute reading, unquoted style, preview images, docs, guard case). Tests watched red first (13 failures across 3 files)
