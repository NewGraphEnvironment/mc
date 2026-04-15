# Issue #25 — preview-md-header

Taught `mc_preview()` to accept a `.md` path in addition to a raw HTML
string. Path input parses frontmatter via `mc_md_meta()` and prepends an
inline-styled header table (To / Cc / optional Bcc / Subject / Thread /
Attach) to the rendered body so envelope mistakes surface locally.
Code-check clean on first round.

Closed via PR #26 (squash-merged as 4916211). Released in v0.2.5.
