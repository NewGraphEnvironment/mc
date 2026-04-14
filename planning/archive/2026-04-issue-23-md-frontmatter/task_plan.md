# Task Plan — issue #23 YAML frontmatter

Adds one-file email workflow: frontmatter metadata in .md + mc_md_* dispatchers.

## Phase 1: Setup
- [x] Branch `md-frontmatter-send`
- [x] PWF scaffold

## Phase 2: YAML parsing foundation
- [ ] Add `yaml` to Imports in DESCRIPTION
- [ ] Teach `strip_md_header()` to also strip YAML frontmatter (leading `---\n...\n---\n`)
- [ ] Add internal `parse_frontmatter(path)` returning `list(meta, body)`
- [ ] Backwards-compat test: existing non-frontmatter drafts render identically

## Phase 3: mc_md_meta()
- [ ] New file `R/mc_md_meta.R`
- [ ] Input validation; return empty `list()` if no frontmatter
- [ ] Roxygen + example
- [ ] Tests

## Phase 4: mc_md_send()
- [ ] New file `R/mc_md_send.R`
- [ ] Args: `path`, `draft = TRUE`, `test = FALSE`, `override = list()`
- [ ] Reads frontmatter, validates required (`to`, `subject`), merges `override`, calls `mc_send()`
- [ ] Roxygen + example
- [ ] Tests (mocked mc_send)

## Phase 5: mc_md_index()
- [ ] New file `R/mc_md_index.R`
- [ ] Args: `dir`, `pattern = "_draft\\.md$"`, `recursive = TRUE`
- [ ] Return tibble-like df with: path, date (from filename YYYYMMDD prefix), to, cc, subject, thread_id, has_attachments
- [ ] Gracefully handle files without frontmatter (NA fields)
- [ ] Roxygen + example
- [ ] Tests using inst/testdata/ or tempdir

## Phase 6: Verify + PR
- [ ] devtools::document()/test()/lint — green
- [ ] /code-check twice
- [ ] PR with SRED tag, PWF archive on merge
