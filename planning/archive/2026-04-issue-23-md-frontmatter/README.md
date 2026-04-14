# Issue #23 — md-frontmatter-send

Added YAML frontmatter support to markdown email drafts, collapsing the old
`.md` + `.R` paired-file pattern into a single frontmattered `.md`. Shipped
three new exports (`mc_md_meta`, `mc_md_send`, `mc_md_index`) and taught
`strip_md_header()` to handle both YAML frontmatter and the legacy compost
header. Code-check surfaced an override-path footgun in `mc_md_send()` and a
silent swallow of malformed YAML in `mc_md_index()`; both fixed before merge.

Closed via PR #24 (squash-merged as ab86ffd). Released in v0.2.4.
