# Task Plan — issue #25 mc_preview() accepts .md path

Teach `mc_preview()` to accept either raw HTML or a `.md` path; when a path,
render frontmatter header (To/Cc/Subject/Thread/Attach) above the body.

## Phase 1: Setup
- [x] Branch `preview-md-header`
- [x] PWF scaffold

## Phase 2: Implementation
- [x] Detect `.md` path vs HTML string in `mc_preview()`
  - Heuristic: string ends with `.md` and `file.exists()` → treat as path
- [x] When path: parse with `mc_md_meta()` and `mc_md_render()`, build an
      HTML header table above the body
- [x] When HTML: existing behavior unchanged
- [x] Header renders empty fields as em-dash, collapses multi-value fields

## Phase 3: Tests
- [x] HTML-string path still works (existing tests continue to pass)
- [x] .md path: header includes subject/to/cc/thread_id/attachments
- [x] .md path without frontmatter still renders body
- [x] .md path with missing optional fields renders em-dashes
- [x] Errors on non-string input

## Phase 4: Verify + PR
- [x] devtools::document()/test()/lint — green
- [x] /code-check
- [x] PR with SRED tag
- [x] Archive PWF on merge
